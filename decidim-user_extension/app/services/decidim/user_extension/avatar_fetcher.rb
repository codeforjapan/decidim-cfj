# frozen_string_literal: true

require "ssrf_filter"

module Decidim
  module UserExtension
    # Fetches a remote avatar image. SsrfFilter resolves the host, refuses
    # private, loopback and link-local addresses (including IPv4 embedded in
    # IPv6), connects to the checked address and checks again on every redirect.
    #
    # Returns [body_io, filename] on success, or nil when the URL is blank,
    # rejected, unreachable, oversized, or the response is non-2xx.
    class AvatarFetcher
      MAX_BYTES = 5 * 1024 * 1024
      TIMEOUT = 5
      MAX_REDIRECTS = 3
      # SsrfFilter tries the next address on a connection failure, timeouts
      # included, so the wait per hop grows with the number of addresses.
      MAX_ADDRESSES = 2

      ALLOWED_CONTENT_TYPES = %w(image/png image/jpeg image/gif image/webp).freeze

      NETWORK_ERRORS = [
        URI::Error,
        SocketError,
        SystemCallError,
        Net::OpenTimeout,
        Net::ReadTimeout,
        IOError,
        OpenSSL::SSL::SSLError
      ].freeze

      HTTP_OPTIONS = { open_timeout: TIMEOUT, read_timeout: TIMEOUT }.freeze

      # Hostless URLs such as "https:foo" make Resolv raise ArgumentError.
      # SsrfFilter only connects to the addresses returned here, so limiting
      # them does not let any other address through.
      RESOLVER = lambda do |hostname|
        hostname.blank? ? [] : SsrfFilter::DEFAULT_RESOLVER.call(hostname).first(MAX_ADDRESSES)
      end

      # SsrfFilter 1.6.0 writes IPv6 hosts into the Host header without
      # brackets. Fixed upstream (arkadiyt/ssrf_filter#100), not yet released.
      SET_HOST_HEADER = ->(request) { request["host"] = request.uri.authority }

      # Redirects are followed in #call so that relative Locations resolve
      # against the current URL (also fixed in arkadiyt/ssrf_filter#100); every
      # hop still goes through SsrfFilter.
      SSRF_OPTIONS = {
        max_redirects: 0,
        allow_unfollowed_redirects: true,
        resolver: RESOLVER,
        request_proc: SET_HOST_HEADER,
        http_options: HTTP_OPTIONS
      }.freeze

      # Raised from the response block to stop reading the body.
      class Rejected < StandardError; end

      def self.call(url, allowed_content_types: ALLOWED_CONTENT_TYPES, default_filename: "avatar")
        new(url, allowed_content_types:, default_filename:).call
      end

      def initialize(url, allowed_content_types: ALLOWED_CONTENT_TYPES, default_filename: "avatar")
        @url = url
        @allowed_content_types = allowed_content_types
        @default_filename = default_filename
      end

      def call
        return nil if @url.blank?

        url = @url
        (MAX_REDIRECTS + 1).times do
          body = nil
          response = SsrfFilter.get(url, SSRF_OPTIONS) { |res| body = read_response(res) }
          unless response.is_a?(Net::HTTPRedirection)
            return nil if body.blank?

            return [StringIO.new(body), File.basename(response.uri&.path.presence || @default_filename)]
          end

          location = response["location"]
          return skip("redirect_without_location") if location.blank?

          url = URI.join(url, location).to_s
        end
        skip("too_many_redirects")
      rescue Rejected => e
        skip(e.message)
      rescue SsrfFilter::Error, Resolv::ResolvError
        skip("unsafe_uri")
      rescue *NETWORK_ERRORS => e
        skip("network_error: #{e.class}")
      end

      private

      # Net::HTTP reads any body left unread after the block, so every
      # response is either read within the limit or rejected here.
      def read_response(response)
        case response
        when Net::HTTPSuccess then read_success(response)
        when Net::HTTPRedirection then discard_body(response)
        else raise Rejected, "http_status_#{response.code}"
        end
      end

      def read_success(response)
        raise Rejected, "unexpected_content_type: #{response["content-type"]}" unless acceptable_content_type?(response["content-type"])
        raise Rejected, "content_length_exceeded" if response["content-length"].to_i > MAX_BYTES

        body = String.new
        response.read_body do |chunk|
          body << chunk
          raise Rejected, "streamed_body_exceeded" if body.bytesize > MAX_BYTES
        end
        body
      end

      def discard_body(response)
        bytes = 0
        response.read_body do |chunk|
          bytes += chunk.bytesize
          raise Rejected, "redirect_body_exceeded" if bytes > MAX_BYTES
        end
        nil
      end

      def acceptable_content_type?(content_type)
        return true if @allowed_content_types.nil?
        return false if content_type.blank?

        mime = content_type.split(";").first.to_s.strip.downcase
        @allowed_content_types.include?(mime)
      end

      def skip(reason)
        Rails.logger.warn { "[Decidim::UserExtension::AvatarFetcher] skipped url=#{@url.inspect} reason=#{reason}" }
        nil
      end
    end
  end
end

# frozen_string_literal: true

require "ipaddr"
require "net/http"
require "resolv"
require "uri"

module Decidim
  module UserExtension
    # Fetches a remote avatar image with SSRF protections.
    #
    # Returns [body_io, filename] on success, or nil when the URL is blank,
    # rejected, unreachable, oversized, or the response is non-2xx.
    class AvatarFetcher
      MAX_BYTES = 5 * 1024 * 1024
      TIMEOUT = 5
      MAX_REDIRECTS = 3

      ALLOWED_CONTENT_TYPES = %w(image/png image/jpeg image/gif image/webp).freeze

      EXTRA_BLOCKED_RANGES = [
        IPAddr.new("0.0.0.0/8"),
        IPAddr.new("100.64.0.0/10"),
        IPAddr.new("192.0.0.0/24"),
        IPAddr.new("198.18.0.0/15"),
        IPAddr.new("224.0.0.0/4"),
        IPAddr.new("240.0.0.0/4"),
        IPAddr.new("::/128"),
        IPAddr.new("ff00::/8")
      ].freeze

      NETWORK_ERRORS = [
        URI::InvalidURIError,
        SocketError,
        Errno::ECONNREFUSED,
        Errno::EHOSTUNREACH,
        Net::OpenTimeout,
        Net::ReadTimeout,
        IOError,
        OpenSSL::SSL::SSLError
      ].freeze

      def self.call(url)
        new(url).call
      end

      def initialize(url)
        @url = url
      end

      def call
        return nil if @url.blank?

        body, filename = fetch(@url, MAX_REDIRECTS)
        return nil if body.blank?

        [StringIO.new(body), filename]
      end

      private

      def fetch(url, redirects_remaining)
        uri = URI.parse(url)
        return skip("unsafe_uri") unless safe_uri?(uri)

        Net::HTTP.start(
          uri.hostname,
          uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: TIMEOUT,
          read_timeout: TIMEOUT
        ) do |http|
          http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
            return handle_response(response, uri, redirects_remaining)
          end
        end
      rescue *NETWORK_ERRORS => e
        skip("network_error: #{e.class}")
      end

      def handle_response(response, uri, redirects_remaining)
        case response
        when Net::HTTPSuccess
          read_success(response, uri)
        when Net::HTTPRedirection
          follow_redirect(response, uri, redirects_remaining)
        else
          skip("http_status_#{response.code}")
        end
      end

      def read_success(response, uri)
        return skip("unexpected_content_type: #{response["content-type"]}") unless image_content_type?(response["content-type"])
        return skip("content_length_exceeded") if response["content-length"].to_i > MAX_BYTES

        body = String.new(capacity: MAX_BYTES)
        response.read_body do |chunk|
          body << chunk
          return skip("streamed_body_exceeded") if body.bytesize > MAX_BYTES
        end

        [body, File.basename(uri.path.presence || "avatar")]
      end

      def follow_redirect(response, uri, redirects_remaining)
        return skip("too_many_redirects") if redirects_remaining <= 0

        location = response["location"]
        return skip("redirect_without_location") if location.blank?

        fetch(URI.join(uri, location).to_s, redirects_remaining - 1)
      end

      def safe_uri?(uri)
        return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        return false if uri.host.blank?

        addresses = Resolv.getaddresses(uri.host)
        return false if addresses.empty?

        addresses.all? { |address| public_ip_address?(address) }
      rescue Resolv::ResolvError
        false
      end

      def public_ip_address?(address)
        ip = IPAddr.new(address)
        return false if ip.loopback?
        return false if ip.private?
        return false if ip.link_local?

        EXTRA_BLOCKED_RANGES.none? { |range| range.include?(ip) }
      rescue IPAddr::InvalidAddressError
        false
      end

      def image_content_type?(content_type)
        return false if content_type.blank?

        mime = content_type.split(";").first.to_s.strip.downcase
        ALLOWED_CONTENT_TYPES.include?(mime)
      end

      def skip(reason)
        Rails.logger.warn { "[Decidim::UserExtension::AvatarFetcher] skipped url=#{@url.inspect} reason=#{reason}" }
        nil
      end
    end
  end
end

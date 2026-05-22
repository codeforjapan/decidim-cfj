# frozen_string_literal: true

module Decidim
  class IframeDisabler
    def initialize(text, _options = {})
      @text = text
    end

    def perform
      @document = Nokogiri::HTML::DocumentFragment.parse(@text)
      disable_iframes(@document)
      document.to_html
    end

    private

    attr_reader :document

    def disable_iframes(node)
      if node.name == "iframe"
        src = node["src"]
        if src && allowed_iframe_domain?(src)
          # iframe is from an allowed domain, leave it as is
        else
          # Default title for accessibility
          node["title"] = I18n.t("decidim.shared.embed.title") if node["title"].blank?
          # Disable scrollbar for some embed services
          node["scrolling"] = "no"
          orig_node = node.to_s
          node.replace(%(<div class="disabled-iframe"><!-- #{orig_node} --></div>))
        end
      end

      node.children.each do |child|
        disable_iframes(child)
      end
    end

    def allowed_iframe_domain?(src)
      allowed_domains = Decidim.config.content_security_policies_extra.dig("frame-src") || [] # rubocop:disable Style/SingleArgumentDig
      return false if allowed_domains.include?("'none'")
      return true if allowed_domains.include?("*")

      begin
        src_uri = URI.parse(src)
        src_scheme = src_uri.scheme
        src_hostname = src_uri.hostname || ""

        allowed_domains.any? do |domain|
          matches_csp_rule?(src_scheme, src_hostname, domain)
        end
      rescue URI::InvalidURIError
        false
      end
    end

    def matches_csp_rule?(src_scheme, src_hostname, domain)
      case domain
      when "'self'"
        false # Self can be handled separately if needed
      when "'none'" # rubocop:disable Lint/DuplicateBranch
        false
      when /^(https?|data|blob):$/
        # Scheme matching
        domain_scheme = domain[0..-2] # Remove trailing colon
        src_scheme == domain_scheme
      when "*"
        true
      else
        # Hostname matching (with optional wildcards and ports)
        match_hostname_rule?(src_hostname, domain)
      end
    end

    def match_hostname_rule?(src_hostname, domain)
      # Extract base hostname from CSP domain (which may include protocol, port, path)
      normalized_domain = extract_hostname(domain)
      return false if normalized_domain.blank?

      # Handle wildcard subdomains (*.example.com)
      if normalized_domain.start_with?("*.")
        base_domain = normalized_domain[2..] # Remove "*."
        src_hostname.end_with?(".#{base_domain}") || src_hostname == base_domain
      else
        src_hostname == normalized_domain || src_hostname.end_with?(".#{normalized_domain}")
      end
    end

    def extract_hostname(domain)
      # Remove 'self', 'none' keywords
      return nil if domain.start_with?("'")

      # Add https:// scheme if not present (but not for bare scheme values like "https:")
      domain_to_parse = if domain.match?(%r{^https?://})
                          domain
                        elsif !domain.include?(":") # rubocop:disable Rails/NegateInclude
                          "https://#{domain}"
                        else
                          # Bare scheme like "https:" - handle separately
                          return nil
                        end

      begin
        uri = URI.parse(domain_to_parse)
        uri.hostname
      rescue URI::InvalidURIError
        # Fallback: try to extract hostname manually
        domain.gsub(%r{^https?://}, "").split("/").first.split(":").first
      end
    end
  end
end

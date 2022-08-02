# frozen_string_literal: true

module OmniAuth
  module Strategies
    # OmniAuth Strategy for LINE Login
    class LineLogin < OmniAuth::Strategies::OAuth2
      option :name, 'line_login'
      option :scope, 'profile openid'

      option :client_options, {
        site: 'https://api.line.me',
        authorize_url: 'https://access.line.me/oauth2/v2.1/authorize',
        token_url: '/oauth2/v2.1/token'
      }

      uid { raw_info['sub'] }

      info do
        {
          user_id: raw_info['sub'],
          name: raw_info['name'],
          email: raw_info['email'],
          image: raw_info['picture']
        }
      end

      def raw_info
        @raw_info ||= verify_id_token
      end

      private

      def authorize_params
        super.tap do |params|
          params[:nonce] = SecureRandom.uuid
          session['omniauth.nonce'] = params[:nonce]
        end
      end

      def callback_url
        full_host + script_name + callback_path
      end

      def verify_id_token
        @id_token_payload ||= client.request(:post, 'https://api.line.me/oauth2/v2.1/verify',
                                             {
                                               body: {
                                                 id_token: access_token['id_token'],
                                                 client_id: options.client_id,
                                                 nonce: session.delete('omniauth.nonce')
                                               }
                                             }).parsed
        Rails.logger.info("token:#{@id_token_payload.inspect}")
        @id_token_payload
      end
    end
  end
end

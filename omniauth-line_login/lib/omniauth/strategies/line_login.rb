# frozen_string_literal: true

module OmniAuth
  module Strategies
    # OmniAuth Strategy for LINE Login
    class LineLogin < OmniAuth::Strategies::OAuth2
      option :name, 'line_login'
      option :scope, 'profile openid'
      option :pkce, true

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
          # email: raw_info['email'],
          image: raw_info['picture']
        }
      end

      def raw_info
        @raw_info ||= verify_id_token
      end

      def callback_phase
        super
      rescue OmniAuth::LineLogin::Error => e
        fail!(:invalid_id_token, e)
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

      def verify_id_token # rubocop:disable Metrics/MethodLength
        nonce = session.delete('omniauth.nonce')
        raise OmniAuth::LineLogin::Error, 'nonce is missing from the session' if nonce.blank?

        @id_token_payload ||= client.request(:post, 'https://api.line.me/oauth2/v2.1/verify',
                                             {
                                               body: {
                                                 id_token: access_token['id_token'],
                                                 client_id: options.client_id,
                                                 nonce: nonce
                                               }
                                             }).parsed
        @id_token_payload
      end
    end
  end
end

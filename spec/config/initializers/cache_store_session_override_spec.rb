# frozen_string_literal: true

require "rails_helper"

describe CacheStoreSessionOverride do
  # Shaped like RedisCacheStore so that reads and writes go through the request-local cache.
  let(:store_class) do
    Class.new(ActiveSupport::Cache::Store) do
      prepend ActiveSupport::Cache::Strategy::LocalCache

      def initialize(*)
        super
        @data = {}
      end

      private

      def read_entry(key, **) = deserialize_entry(read_serialized_entry(key, **))

      def read_serialized_entry(key, **) = @data[key]

      def write_entry(key, entry, **) = write_serialized_entry(key, serialize_entry(entry, **), **)

      def write_serialized_entry(key, payload, **)
        @data[key] = payload
        true
      end

      def delete_entry(key, **) = !@data.delete(key).nil?
    end
  end
  let(:cache) { stub_const("LocallyCachedStore", store_class).new }
  let(:rack_errors) { StringIO.new }
  let(:app) do
    lambda do |env|
      request = ActionDispatch::Request.new(env)
      case request.path
      when "/set"
        request.session[:foo] = "bar"
      when "/reset"
        request.session[:foo]
        request.reset_session
        request.session[:bar] = "baz"
      when "/renew"
        request.session[:foo]
        request.session_options[:renew] = true
        request.session[:bar] = "baz"
      when "/read_while_signing_out"
        request.session[:foo]
        sign_out_concurrently.call(env["HTTP_COOKIE"])
      when "/write_while_signing_out"
        request.session[:foo]
        sign_out_concurrently.call(env["HTTP_COOKIE"])
        request.session[:foo] = "baz"
      end
      [200, {}, [request.session.to_hash.slice("foo", "bar").to_json]]
    end
  end
  let(:sign_out_concurrently) do
    ->(cookie) { Thread.new { call_stack.call("/reset", cookie) }.join }
  end
  let(:stack) do
    store = ActionDispatch::Session::CacheStore.new(app, cache:, key: "decidim_session", expire_after: 30.minutes)
    cache.middleware.new(ActionDispatch::Cookies.new(store))
  end
  let(:call_stack) do
    lambda do |path, cookie = nil|
      env = Rails.application.env_config.merge(
        Rack::MockRequest.env_for("https://example.org#{path}", "HTTP_COOKIE" => cookie, "rack.errors" => rack_errors)
      )
      status, headers, body = stack.call(env)
      text = +""
      body.each { |chunk| text << chunk }
      body.close if body.respond_to?(:close)
      { status:, cookie: headers["Set-Cookie"]&.split(";")&.first, body: JSON.parse(text) }
    end
  end
  let!(:cookie) { call_stack.call("/set")[:cookie] }

  it "keeps the session when nothing deletes it" do
    expect(call_stack.call("/get", cookie)[:body]).to eq("foo" => "bar")
  end

  it "does not restore a session deleted while the request was reading it" do
    result = call_stack.call("/read_while_signing_out", cookie)

    expect(result[:cookie]).to be_nil
    expect(call_stack.call("/get", cookie)[:body]).to eq({})
  end

  it "does not restore a session deleted while the request was writing it" do
    result = call_stack.call("/write_while_signing_out", cookie)

    expect(result[:cookie]).to be_nil
    expect(call_stack.call("/get", cookie)[:body]).to eq({})
  end

  it "saves a session reset by the request itself under the new id" do
    new_cookie = call_stack.call("/reset", cookie)[:cookie]

    expect(new_cookie).not_to eq(cookie)
    expect(call_stack.call("/get", new_cookie)[:body]).to eq("bar" => "baz")
    expect(call_stack.call("/get", cookie)[:body]).to eq({})
  end

  it "saves a session renewed by the request itself under the new id" do
    new_cookie = call_stack.call("/renew", cookie)[:cookie]

    expect(new_cookie).not_to eq(cookie)
    expect(call_stack.call("/get", new_cookie)[:body]).to eq("foo" => "bar", "bar" => "baz")
    expect(call_stack.call("/get", cookie)[:body]).to eq({})
  end
end

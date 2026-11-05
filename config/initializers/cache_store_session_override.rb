# frozen_string_literal: true

# Same as ActionDispatch::Session::CacheStore#find_session/#write_session in Rails 8.0.5.2:
# skip writing back a session whose cache entry another request deleted (e.g. reset_session
# on sign out) while this request was running. Remove once the CacheStore of the Rails in use
# does this itself (8.0.5.2 does; 7.2.3.2 and 8.1.4 do not).
module CacheStoreSessionOverride
  LOADED_SESSION_ID = "action_dispatch.session.cache_store.loaded_session_id"

  def find_session(req, sid)
    if sid && (session = get_session_with_fallback(sid))
      req.set_header(LOADED_SESSION_ID, sid.private_id)
    else
      sid = generate_sid
      session = {}
    end
    [sid, session]
  end

  def write_session(req, sid, session, options)
    return false if session && destroyed_since_loaded?(req, sid)

    super
  end

  private

  def destroyed_since_loaded?(req, sid)
    req.get_header(LOADED_SESSION_ID) == sid.private_id &&
      !exist_in_backend?(cache_key(sid.private_id)) &&
      !exist_in_backend?(cache_key(sid.public_id))
  end

  # The request-local cache still holds the entry this request loaded, so
  # a lookup through it cannot see a delete made by another request.
  def exist_in_backend?(key)
    if @cache.respond_to?(:with_local_cache)
      @cache.with_local_cache { @cache.exist?(key) }
    else
      @cache.exist?(key)
    end
  end
end

ActionDispatch::Session::CacheStore.prepend(CacheStoreSessionOverride)

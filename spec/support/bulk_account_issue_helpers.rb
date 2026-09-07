# frozen_string_literal: true

RSpec.shared_context "with another bulk issue running" do
  def with_lock_held_elsewhere(organization)
    lock_id = Decidim::BulkSpaceAccountIssuer.advisory_lock_id(organization)
    connection = ActiveRecord::Base.connection_pool.checkout
    raise "could not take the lock from another connection" unless connection.get_advisory_lock(lock_id)

    yield
  ensure
    if connection
      connection.release_advisory_lock(lock_id)
      ActiveRecord::Base.connection_pool.checkin(connection)
    end
  end
end

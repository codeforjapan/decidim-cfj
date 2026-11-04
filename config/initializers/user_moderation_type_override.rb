# frozen_string_literal: true

# Decidim::Core::UserModerationType が `object.blocking` の nil を想定しておらず、
# 公開 GraphQL エンドポイントを落としている問題への対処。
#
# `moderatedUsers` の collection は `decidim_users.blocked_at` で絞り込むが
# (decidim-api/lib/decidim/api/query_type.rb)、型のリゾルバは
# `decidim_users.block_id` 経由の `has_one :blocking` が存在する前提で
# `justification` / `blocking_user` を呼ぶ。blocked_at は入っているが block_id が
# NULL のユーザーが 1 件でもあると `{ moderatedUsers { blockReasons } }` が
# NoMethodError になる。フィールドは null: true なのにガードが無い。
#
# open_data_blocked_user_serializer_override.rb と根本原因は同一
# (collection は blocked_at、consumer は block_id を前提)。UserModerationType は
# 0.32 で新規に追加された型で、0.30 / 0.31 には存在しない。
Rails.application.config.to_prepare do
  Decidim::Core::UserModerationType

  module DecidimCoreUserModerationTypeNilBlockingPatch
    def block_reasons
      object.blocking&.justification
    end

    def blocking_user
      object.blocking&.blocking_user
    end
  end

  Decidim::Core::UserModerationType.prepend(DecidimCoreUserModerationTypeNilBlockingPatch)
end

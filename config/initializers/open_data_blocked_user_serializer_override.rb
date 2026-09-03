# frozen_string_literal: true

# Decidim::Exporters::OpenDataBlockedUserSerializer が `resource.blocking` の nil を
# 想定しておらず、オープンデータのエクスポート全体を落としている問題への対処。
#
# moderated_users の collection は `decidim_users.blocked_at` で絞り込むが
# (decidim-core/lib/decidim/core.rb の open_data_manifests)、serializer は
# `decidim_users.block_id` 経由の `has_one :blocking` が存在する前提で
# `justification` を呼ぶ。blocked_at は入っているが block_id が NULL のユーザーが
# 1 件でもあると NoMethodError になり、ZIP 生成が moderated_users の時点で中断されるため
# 提案も会議もユーザーも一切出力されず、/open-data/download が 302 を返し続ける。
#
# 本番実測 (30日): start 6,215 / done 588 (完走率 9.5%)。
# 失敗 5,565 件のうち 5,536 件 (99.5%) がこの NoMethodError。
#
# decidim 0.30.9 / 0.31.7 / 0.32.1 のいずれでも当該 serializer は同一内容で未修正のため、
# 上流追従では解消しない。
#
# NOTE: 元実装が `resource.blocking.justification` を直接呼ぶ構造のため super は使えない
# (super の中で例外が起きる)。serialize 全体を差し替える。
# 元は decidim-core/app/serializers/decidim/exporters/open_data_blocked_user_serializer.rb
# の v0.30.9 時点の実装で、v0.31.7 / v0.32.1 とも差分なし。
Rails.application.config.to_prepare do
  Decidim::Exporters::OpenDataBlockedUserSerializer # rubocop:disable Lint/Void

  module DecidimExportersOpenDataBlockedUserSerializerNilBlockingPatch
    def serialize
      blocking = resource.blocking
      blocking_user = blocking&.blocking_user

      {
        user_id: resource.user.id,
        blocked_at: resource.user.blocked_at,
        about: resource.user.about,
        reasons: resource.reports.map(&:reason),
        details: resource.reports.map(&:details),
        block_reasons: blocking&.justification,
        blocking_user: blocking_user&.presenter&.name
      }
    end
  end

  Decidim::Exporters::OpenDataBlockedUserSerializer.prepend(
    DecidimExportersOpenDataBlockedUserSerializerNilBlockingPatch
  )
end

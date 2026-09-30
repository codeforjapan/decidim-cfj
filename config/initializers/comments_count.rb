# frozen_string_literal: true

Rails.application.config.to_prepare do
  # 各コンポーネントの comments_count を、実データの合計で上書きする。
  #
  # コンポーネントは gem ごと削除されうる（0.32 で decidim-sortitions が消えた）。
  # 1 件の nil manifest で同じブロック内の他の登録まで道連れにしないよう、
  # manifest が見つからないものは飛ばす。
  comments_counters = {
    accountability: lambda { |components, start_at, end_at|
      Decidim::Accountability::FilteredResults.for(components, start_at, end_at).sum(:comments_count)
    },
    blogs: lambda { |components, start_at, end_at|
      Decidim::Blogs::FilteredPosts.for(components, start_at, end_at).sum(:comments_count)
    },
    debates: lambda { |components, start_at, end_at|
      Decidim::Debates::FilteredDebates.for(components, start_at, end_at).sum(:comments_count)
    }
  }

  comments_counters.each do |manifest_name, counter|
    manifest = Decidim.find_component_manifest(manifest_name)
    next if manifest.blank?

    manifest.stats.stats.reject! { |s| s[:name] == :comments_count }
    manifest.register_stat :comments_count, tag: :comments do |components, start_at, end_at|
      counter.call(components, start_at, end_at)
    end
  end
end

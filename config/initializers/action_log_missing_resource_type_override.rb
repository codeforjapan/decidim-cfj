# frozen_string_literal: true

# 削除・改名されたクラス名（resource_type / item_type）の記録があると、管理ログと
# 管理ダッシュボードが NameError で 500 になる（decidim#17728）。
# 該当クラスが無い記録は関連先が無いものとして扱い、記録時のタイトルで表示する。
Rails.application.config.to_prepare do
  module DecidimMissingPolymorphicClassPatch
    # 関連の読み込み（includes を含む）で使われる。nil を返すと関連先は nil になる。
    def polymorphic_class_for(name)
      return if name.safe_constantize.nil?

      super
    end
  end

  module DecidimActionLogMissingResourceTypePatch
    def lazy_relation(id_method, klass_name, cache)
      return if klass_name.safe_constantize.nil?

      super
    end
  end

  Decidim::ActionLog.singleton_class.prepend(DecidimMissingPolymorphicClassPatch)
  Decidim::ActionLog.singleton_class.prepend(DecidimActionLogMissingResourceTypePatch)
  # 差分表示（version.changeset）が version.item を読む。
  PaperTrail::Version.singleton_class.prepend(DecidimMissingPolymorphicClassPatch)
end

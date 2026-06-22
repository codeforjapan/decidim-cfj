# frozen_string_literal: true

# DecidimAwesome::Config#sub_configs_for のN+1クエリ修正
#
# 元の実装はサブ設定キーごとに AwesomeConfig.find_by を個別実行するため、
# proposals ページで 19クエリ/リクエスト 発生していた。
# initialize 時に一括取得済みの @vars からRubyレベルで検索することで解消する。
Decidim::DecidimAwesome::Config.prepend(Module.new do
  def sub_configs_for(singular_key)
    return @sub_configs[singular_key] if @sub_configs[singular_key]

    plural_key = singular_key.pluralize.to_sym
    return {} unless config[plural_key]

    @sub_configs[singular_key] = config[plural_key].to_h do |key, _value|
      [key, @vars.find { |v| v.var == "#{singular_key}_#{key}" }]
    end
  end
end)

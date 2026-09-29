# frozen_string_literal: true

# 管理画面のエディタに読み込む本文で、リンク先(href / src)に入った Global ID を
# 実際の URL に戻す。
#
# Decidim は保存時に Decidim::ContentParsers::ResourceParser#parse_for_urls が
# 本文中のリソース URL を gid:// へ書き換える。これは上流の意図した仕様で、
# 参加スペースの slug が変わってもリンクが切れないようにするためのもの。
# 問題は gid を元に戻す処理が「公開画面の表示」にしか無いこと。
#
#   - 公開画面: 0.31 で修正済み。0.30 へは content_renderers_context_override.rb
#     (decidim/decidim#16545 のバックポート)が対応する
#   - 管理画面のエディタ: どのバージョンにも無い。tiptap の Link 拡張は
#     parseHTML / renderHTML の両方で href のスキームを検査し、許可外なら
#     リンクごと破棄するため、編集画面を開いて保存しただけでリンクが消える
#
# 保存側の ResourceParser は v0.30.9 と v0.32.1 でバイト単位で同一なので、
# バージョンを上げても後者は解消しない。このファイルは 0.31 / 0.32 でも必要。
#
# ## 相対パスではなく絶対 URL に戻す理由
#
# 保存側は URL_REGEX_SCHEME = '(?:http(s)?:\/\/)' でスキームを要求する。
# 相対パスに戻すと保存時に gid へ戻らず、生パスのまま保存されて slug 変更耐性を
# 失う。絶対 URL なら「gid → URL → 保存 → 同じ gid」で往復が閉じる。
#
# ## 本文テキスト中の gid には触れない理由
#
# 既存のレンダラを通すと display_mention が <a> タグを生成し、管理者が編集する
# 対象そのものが変わってしまう。ここで直したいのは href に入った gid だけ。
#
# ## content_renderers_context_override.rb に相乗りしない理由
#
# あちらは 0.31 で撤去できる(上流が取り込み済み)が、こちらは保存側が未修正の
# ため 0.32 以降も要る。撤去時期が違うものに実装を依存させると、あちらを消した
# 瞬間に上流の同名メソッドへ切り替わり、シグネチャ差が silent breakage になる。
# 必要なのは属性の走査だけなので自前で持つ。
module DecidimCfjEditorResourceLink
  # gid://<app>/<Class>/<id> 。リソース種別は絞らない。
  # Proposal / Meeting 以外(ユーザーメンション等)も href に入りうるため、
  # 「URL を持つものは戻す」という規則で統一する。
  GID_PATTERN = %r{gid://[\w-]+/[A-Za-z0-9:_]+/\d+}
  # href / src 以外にリンク先が入る属性は Decidim のエディタでは使わない。
  LINK_ATTRIBUTES = %w(href src).freeze

  module_function

  # 属性内の gid だけを絶対 URL に置き換える。解決できないものは元のまま残す。
  def rewrite(html)
    # 大半の本文には gid が無い。cast_value は属性読み出しのたびに走るため、
    # Nokogiri のパースに入る前に弾く。
    return html unless html.is_a?(String) && html.include?("gid://")

    fragment = Nokogiri::HTML.fragment(html)
    # Nokogiri の traverse は Enumerator を返さないためブロックで受ける。
    modified = false
    fragment.traverse { |node| modified = true if node.element? && rewrite_node(node) }

    modified ? fragment.to_html : html
  end

  # 1要素ぶんの href / src を書き換える。実際に変わったら true。
  def rewrite_node(node)
    LINK_ATTRIBUTES.count { |attribute| rewrite_attribute(node, attribute) }.positive?
  end

  def rewrite_attribute(node, attribute)
    value = node[attribute]
    return false if value.blank? || value.exclude?("gid://")

    replaced = value.gsub(GID_PATTERN) { |gid| resource_url(gid) || gid }
    return false if replaced == value

    node[attribute] = replaced
    true
  end

  # 解決できない gid(削除済みリソース、URL を持たない種別)は nil を返し、
  # 呼び出し側が元の gid を温存する。href を空にするとリンクが消えてしまうため。
  def resource_url(gid)
    resource = GlobalID::Locator.locate(gid)
    return if resource.blank?

    Decidim::ResourceLocatorPresenter.new(resource).url
  rescue StandardError
    # locate の失敗(RecordNotFound など)も、ルーティングを引けない種別も、
    # ここでは同じく「戻せなかった」として扱う。エディタを開けなくする方が害が大きい。
    nil
  end
end

Rails.application.config.to_prepare do
  Decidim::Attributes::RichText # rubocop:disable Lint/Void

  Decidim::Attributes::RichText.class_eval do
    # DB → フォームオブジェクト方向。form_builder#editor が出力する hidden_field は
    # このゲッターを通るため、エディタに渡る値はここを必ず経由する
    # (多言語フィールドの場合はロケールごとの String に対して1回ずつ呼ばれる)。
    def cast_value(value)
      DecidimCfjEditorResourceLink.rewrite(super)
    end
  end
end

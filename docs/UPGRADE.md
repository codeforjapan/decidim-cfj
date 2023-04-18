# 更新作業について

このインスタンスはDecicim本体に依存しており、Decidimが更新された場合、それに合わせて更新作業を行う必要があります。

## Decidimの更新方法

基本的な手順は https://docs.decidim.org/en/install/update/ に書いてある通りです。

## Decidim本体のバージョン更新時に特に注意したい内容

Decidim本体のバージョンを更新する際、特に注意が必要な内容についてまとめておきます。

### 上書き用のファイル・ディレクトリ

このDecidimアプリ内で、Decidim本体やライブラリに含まれる元ファイルを上書きしているファイルがいくつかあります。
これらのファイルについては、Decidim本体のファイルがバージョンアップ時に更新された場合、その更新内容をファイルに反映させなければアプリケーションが壊れる可能性があります。そのため、本体の更新時には確認が必要です。

* `app/packs/src/decidim/decidim_awesome/editors/editor.js`

  QuillエディタでHTML編集ができるようにするために追加されたファイル。現在はDecidim Awesome対応になっています(decidim_awesome内の`app/packs/src/decidim/decidim_awesome/editors/editor.js`がベースになっています)。

* `app/packs/stylesheets/decidim/cfj/buttons.scss`

  `https://github.com/codeforjapan/decidim-cfj/issues/46` の対応で `https://github.com/codeforjapan/decidim-cfj/pull/96` で追加しています。

* `app/packs/stylesheets/decidim/cfj/comment_content.scss`

  https://github.com/codeforjapan/decidim-cfj/pull/337 で追加されたファイル。コメント本文の改行をCSSで制御するためのものです。

* `app/packs/stylesheets/decidim/cfj/forms.scss`

  https://github.com/codeforjapan/decidim-cfj/pull/94 で追加されたファイル。職業欄の見た目を修正するためのもの。

* `app/packs/stylesheets/decidim/cfj/media_print.scss`

  https://github.com/codeforjapan/decidim-cfj/pull/460 で追加されたファイル。印刷用のCSSファイル。

* `app/packs/stylesheets/decidim/cfj/ql_html_editor.scss`

  https://github.com/codeforjapan/decidim-cfj/pull/469 で追加されたファイル。Quill HTML Editor用のCSSファイル。

* `app/packs/stylesheets/decidim/cfj/search.scss`

  https://github.com/codeforjapan/decidim-cfj/pull/348 で追加されたファイル。グローバル検索が日本語では機能していないため削除したもの。

* `app/controllers/decidim/debates/versions_controller.rb`

  https://github.com/codeforjapan/decidim-cfj/pull/359 で追加したファイル。履歴の差分が巨大になるとサーバ負荷が大きいため、renderを実行させないよう表示前にredirectさせるものです。

* `app/forms/decidim/debates/close_debate_form.rb`

  https://github.com/codeforjapan/decidim-cfj/pull/415 で追加されたファイル。ディベートでconclusionsに空文字列を許すための修正。

* `decidim-comments`

  https://github.com/codeforjapan/decidim-cfj/issues/319 などの対応のために追加されたディレクトリ(gem)。

  本家の https://github.com/decidim/decidim/tree/develop/decidim-comments から切り出して修正を加えたもの。
  バージョンアップ時には注意しつつ、変更点を適宜修正する必要があります。

* `app/uploaders/decidim/cw/application_uploader.rb`

  https://github.com/decidim/decidim/issues/6720 や https://github.com/codeforjapan/decidim-cfj/issues/101 などの対応のために導入。

* `app/uploaders/decidim/image_uploader.rb`

  https://github.com/codeforjapan/decidim-cfj/pull/455 で追加したもの。ピクセル数の大きい画像に対応するため、max_image_height_or_widthの値を変更している。

* `app/views/decidim/blogs/posts/show.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/107 の対応として https://github.com/codeforjapan/decidim-cfj/pull/126 で追加しています。

#### `decidim-user_extension`について

`decidim-user_extension`はカスタムモジュールとして追加されているものです。このモジュール内にもDecidim本体に依存している箇所があります。

* `decidim-user_extension/app/overrides/decidim/admin/officializations/index/user_extension_modal_override.html.erb.deface`, `decidim-user_extension/app/overrides/decidim/admin/officializations/index/user_extension_override.html.erb.deface`

管理画面のビュー `decidim-admin/app/views/decidim/admin/officializations/index.html.erb` を上書きしています。

* `decidim-user_extension/app/views/decidim/devise/registrations/new.html.erb`, `decidim-user_extension/app/views/decidim/devise/registrations/_user_extension.html.erb`

入力フォーム `decidim-core/app/views/decidim/devise/registrations/new.html.erb` を上書きしています。

* `decidim-user_extension/app/views/decidim/account/show.html.erb`, `decidim-user_extension/app/views/decidim/account/_user_extension.html.erb`

`decidim-core/app/views/decidim/account/show.html.erb` を上書きしています。

* `lib/decidim/map/provider/static_map`以下

`Decidim::Map::Provider::StaticMap::CfjOsm`という独自のstatic map providerを定義するためのものです。
`config/initializers/decidim.rb`のconfig.maps以下のstaticのところで導入されています。

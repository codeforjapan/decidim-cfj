# 更新作業について

このインスタンスはDecicim本体に依存しており、Decidimが更新された場合、それに合わせて更新作業を行う必要があります。

## Decidimの更新方法

基本的な手順は https://docs.decidim.org/en/install/update/ に書いてある通りです。

## Decidim本体のバージョン更新時に特に注意したい内容

Decidim本体のバージョンを更新する際、特に注意が必要な内容についてまとめておきます。

### 上書き用のファイル・ディレクトリ

このDecidimアプリ内で、Decidim本体やライブラリに含まれる元ファイルを上書きしているファイルがいくつかあります。
これらのファイルについては、Decidim本体のファイルがバージョンアップ時に更新された場合、その更新内容をファイルに反映させなければアプリケーションが壊れる可能性があります。そのため、本体の更新時には確認が必要です。

* `app/commands/decidim/accountability/destroy_all_results.rb`,
  `app/commands/decidim/areas/destroy_all_areas.rb`,
  `app/commands/decidim/assemblies/destroy_all_assemblies.rb`,
  `app/commands/decidim/blogs/destroy_all_posts.rb`,
  `app/commands/decidim/budgets/destroy_all_budgets.rb`,
  `app/commands/decidim/comments/destroy_all_comments.rb`,
  `app/commands/decidim/debates/destroy_all_debates.rb`,
  `app/commands/decidim/destroy_all_attachments.rb`,
  `app/commands/decidim/gamifications/destroy_all_badges.rb`,
  `app/commands/decidim/meetings/destroy_all_meetings.rb`,
  `app/commands/decidim/messaging/destroy_all_messages.rb`,
  `app/commands/decidim/organizations/destroy_organization.rb`,
  `app/commands/decidim/pages/destroy_all_pages.rb`,
  `app/commands/decidim/participatory_processes/destroy_all_participatory_processes.rb`,
  `app/commands/decidim/proposals/destroy_all_proposals.rb`,
  `app/commands/decidim/surveys/destroy_all_surveys.rb`

  `delete:destroy_all`タスクで不要なレコードを消せるように追加されたファイル。 https://github.com/codeforjapan/decidim-cfj/pull/501 で追加されたものです。

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

* `app/models/decidim/searchable_resource.rb`

  https://github.com/codeforjapan/decidim-cfj/pull/615 で追加したファイル。pg_searchのfeatureとしてbigram(`pg_bigm`)に対応させるためのもの。

* `app/uploaders/decidim/cw/application_uploader.rb`

  https://github.com/decidim/decidim/issues/6720 や https://github.com/codeforjapan/decidim-cfj/issues/101 などの対応のために導入。

* `app/uploaders/decidim/image_uploader.rb`

  https://github.com/codeforjapan/decidim-cfj/pull/455 で追加したもの。ピクセル数の大きい画像に対応するため、max_image_height_or_widthの値を変更している。

* `lib/tasks/delete.rake`

  `delete:destroy_all`タスク。https://github.com/codeforjapan/decidim-cfj/pull/501 で追加されたものです。

* `lib/tasks/comment.rake`

  `comment:remove_orphans`タスク。https://github.com/codeforjapan/decidim-cfj/pull/454 で追加されたものです。

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

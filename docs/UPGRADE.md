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

* `app/packs/stylesheets/buttons.scss`

  `https://github.com/codeforjapan/decidim-cfj/issues/46` の対応で `https://github.com/codeforjapan/decidim-cfj/pull/96` で追加しています。

* `app/commands/decidim/admin/process_participatory_space_private_user_import_csv.rb`

  https://github.com/codeforjapan/decidim-cfj/issues/202 の対応のため追加したファイル。

  https://github.com/decidim/decidim/pull/7781 で本家にフィードバックしたので、これが取り込まれたバージョン(v0.25.0以降)になればファイルごと削除できるはずです。

* `app/controllers/decidim/debates/versions_controller.rb`

  https://github.com/codeforjapan/decidim-cfj/pull/359 で追加したファイル。履歴の差分が巨大になるとサーバ負荷が大きいため、renderを実行させないよう表示前にredirectさせるものです。

* `app/forms/decidim/proposals/proposal_wizard_create_step_form.rb`, `app/forms/decidim/proposals/admin/proposal_form.rb`

  https://github.com/codeforjapan/decidim-cfj/issues/23 の対応のために追加されたもの。対応するPRは https://github.com/codeforjapan/decidim-cfj/pull/60 https://github.com/codeforjapan/decidim-cfj/pull/163 です。
  EtiquetteValidatorは修正が入っているので戻せるかもしれませんが、8文字程度のタイトルでも許可するようにする修正はフィードバックできていません。

* `decidim-comments`

  https://github.com/codeforjapan/decidim-cfj/issues/319 などの対応のために追加されたディレクトリ(gem)。

  本家の https://github.com/decidim/decidim/tree/develop/decidim-comments から切り出して修正を加えたもの。
  バージョンアップ時には注意しつつ、変更点を適宜修正する必要があります。

* `app/helpers/decidim/resource_versions_helper.rb`

  高速化のために https://github.com/codeforjapan/decidim-cfj/pull/289 で追加されたファイル。

  https://github.com/decidim/decidim/pull/8393 でフィードバック済みなので、取り込まれたバージョンでは削除できます。

* `app/uploaders/decidim/cw/application_uploader.rb`

  https://github.com/decidim/decidim/issues/6720 や https://github.com/codeforjapan/decidim-cfj/issues/101 などの対応のために導入。

* `app/views/decidim/application/_collection.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/192 の対応で https://github.com/codeforjapan/decidim-cfj/pull/210 で追加しています。
  本家の https://github.com/decidim/decidim/pull/7418 で対応済みなので、取り込まれたバージョンでは削除できます。

* `app/views/decidim/blogs/posts/show.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/107 の対応として https://github.com/codeforjapan/decidim-cfj/pull/126 で追加しています。

* `app/views/layouts/decidim/_main_footer.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/101 の対応として https://github.com/codeforjapan/decidim-cfj/pull/108 で追加しています。
  ダウンロードに問題がなければ削除しても大丈夫かと思われます。

#### `decidim-user_extension`について

`decidim-user_extension`はカスタムモジュールとして追加されているものです。このモジュール内にもDecidim本体に依存している箇所があります。

* `decidim-user_extension/app/overrides/decidim/admin/officializations/index/user_extension_modal_override.html.erb.deface`, `decidim-user_extension/app/overrides/decidim/admin/officializations/index/user_extension_override.html.erb.deface`

管理画面のビュー `decidim-admin/app/views/decidim/admin/officializations/index.html.erb` を上書きしています。

* `decidim-user_extension/app/views/decidim/devise/registrations/new.html.erb`, `decidim-user_extension/app/views/decidim/devise/registrations/_user_extension.html.erb`

入力フォーム `decidim-core/app/views/decidim/devise/registrations/new.html.erb` を上書きしています。

* `decidim-user_extension/app/views/decidim/account/show.html.erb`, `decidim-user_extension/app/views/decidim/account/_user_extension.html.erb`

`decidim-core/app/views/decidim/account/show.html.erb` を上書きしています。

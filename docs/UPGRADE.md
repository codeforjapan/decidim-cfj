# 更新作業について

このインスタンスはDecicim本体に依存しており、Decidimが更新された場合、それに合わせて更新作業を行う必要があります。

## Decidimの更新方法

基本的な手順は https://docs.decidim.org/en/install/update/ に書いてある通りです。

## Decidim本体のバージョン更新時に特に注意したい内容

Decidim本体のバージョンを更新する際、特に注意が必要な内容についてまとめておきます。

### 上書き用のファイル・ディレクトリ

このDecidimアプリ内で、Decidim本体やライブラリに含まれる元ファイルを上書きしているファイルがいくつかあります。
これらのファイルについては、Decidim本体のファイルがバージョンアップ時に更新された場合、その更新内容をファイルに反映させなければアプリケーションが壊れる可能性があります。そのため、本体の更新時には確認が必要です。

* `app/assets/javascripts/decidim/decidim_awesome/editors/legacy_quill_editor.js.es6`

  QuillエディタでHTML編集ができるようにするために追加されたファイル。現在はDecidim Awesome対応になっています(decidim_awesome内の`app/assets/javascripts/decidim/decidim_awesome/editors/legacy_quill_editor.js.es6`がベースになっています)。

* `app/assets/stylesheets/buttons.scss`

  `https://github.com/codeforjapan/decidim-cfj/issues/46` の対応で `https://github.com/codeforjapan/decidim-cfj/pull/96` で追加しています。

* `app/assets/stylesheets/decidim/decidim_awesome/editors/quill_editor.scss`

  Decidim Awesomeを追加した際に https://github.com/codeforjapan/decidim-cfj/pull/223 で上書きしています。

* `app/commands/decidim/admin/process_participatory_space_private_user_import_csv.rb`

  https://github.com/codeforjapan/decidim-cfj/issues/202 の対応のため追加したファイル。

  https://github.com/decidim/decidim/pull/7781 で本家にフィードバックしたので、これが取り込まれたバージョンになればファイルごと削除できるはずです。

* `decidim-comments`

  https://github.com/codeforjapan/decidim-cfj/issues/319 などの対応のために追加されたディレクトリ(gem)。

  本家の https://github.com/decidim/decidim/tree/develop/decidim-comments から切り出して修正を加えたもの。
  バージョンアップ時には注意しつつ、変更点を適宜修正する必要があります。

* `app/helpers/decidim/resource_versions_helper.rb`

  高速化のために https://github.com/codeforjapan/decidim-cfj/pull/289 で追加されたファイル。

  https://github.com/decidim/decidim/pull/8393 でフィードバック済みなので、取り込まれたバージョンでは削除できます。

* `app/uploaders/decidim/application_uploader.rb`

  https://github.com/decidim/decidim/issues/6720 や https://github.com/codeforjapan/decidim-cfj/issues/101 などの対応のために導入。

* `app/views/decidim/application/_collection.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/192 の対応で https://github.com/codeforjapan/decidim-cfj/pull/210 で追加しています。
  本家の https://github.com/decidim/decidim/pull/7418 で対応済みなので、取り込まれたバージョンでは削除できます。

* `app/views/decidim/blogs/posts/show.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/107 の対応として https://github.com/codeforjapan/decidim-cfj/pull/126 で追加しています。


* `app/views/decidim/proposals/admin/proposals/_form.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/24 の対応として https://github.com/codeforjapan/decidim-cfj/pull/51 で追加しています。
  本家には https://github.com/decidim/decidim/issues/6739 でフィードバック済で、再現まではできてようですが、修正されたかどうかは不明です。

* `app/views/layouts/decidim/_main_footer.html.erb`

  https://github.com/codeforjapan/decidim-cfj/issues/101 の対応として https://github.com/codeforjapan/decidim-cfj/pull/108 で追加しています。
  ダウンロードに問題がなければ削除しても大丈夫かと思われます。

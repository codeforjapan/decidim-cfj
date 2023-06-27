# imagemagick7

このサイトではimagemagickのver. 7を使っています。これはAlpineの公式パッケージで導入しています。

しかしながら、現在GitHub Actionsで使っているUbuntu 22.04のimagemagickは6で、7を使うには都度ソースからビルドする必要があります。

これを回避するため、imagemagick公式のバイナリをこのディレクトリ内のbin/convertに置き、GitHub Actionsではこれを利用するようにしています。
公式のバイナリはimamagickの公式サイトで配布しているもので、AppImageによるportableなバイナリになっています。

* https://imagemagick.org/script/download.php

現在使用しているバージョンは`Version: ImageMagick 7.1.1-6 Q16-HDRI x86_64 1be141ef8:20230402`です。

参考: バイナリを導入したpull request: https://github.com/codeforjapan/decidim-cfj/pull/527

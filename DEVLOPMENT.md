# 開発者向け情報

## 1. 環境構築


| アプリケーション名 | バージョン |
| ------- | ------- |
|[Ruby](https://www.ruby-lang.org/ja/)|2.6.6|
|[Bundler](https://bundler.io/)|1.17.3 |
|[PostgreSQL](https://www.postgresql.org/)|13 |

### 1-1. 事前準備
- rbenvのインストール（macOSならhomebrew経由）
- PostgreSQLのインストール
- ImageMagickのインストール（macOSならhomebrew経由）

## 2. 実行
### 2.1 Rubyのインストール
```
rbenv install 2.6.6
```
### 2.2 レポジトリをクローン
```
git clone git@github.com:codeforjapan/decidim-cfj.git

```
### 2.3 masterブランチへチェックアウト
```
cd decidim-cfj
# masterブランチが最新
git checkout -b master origin/master
```
### 2.4 bundlerのインストール
```
gem install bundler:1.17.3
```

### 2.5 DBのユーザーとパスワードの設定
```
export DATABASE_USERNAME=<yourname>
export DATABASE_PASSWORD=<yourpassword>
```

### 2.6 bundle install
```
bundle install
```
### 2.7 言語の設定
```bash
# default_localeを`:en`にセットする
vim config/initializers/decidim.rb

# before
config.default_locale = :ja
# after
config.default_locale = :en
```
### 2.8 DB作成からシードまで
```
bin/rails db:create db:migrate
bin/rails db:seed
```
### 2.9 サーバー起動
bin/rails s 

### 2.10 お疲れさまでした
http://localhost:3000 にアクセス

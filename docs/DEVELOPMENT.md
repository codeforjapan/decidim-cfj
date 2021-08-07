# 開発者向け情報

[AWS環境へのデプロイ方法](./DEPLOYMENT.md)

## 1. 環境構築
Dockerで環境を構築する際は、1.環境構築と2. 実行（ローカルバージョン）は不要です。
直接、3. 実行（Dockerバージョン）から開始してください。

| アプリケーション名 | バージョン |
| ------- | ------- |
|[Ruby](https://www.ruby-lang.org/ja/)|2.6.6|
|[Bundler](https://bundler.io/)|1.17.3 |
|[PostgreSQL](https://www.postgresql.org/)|13 |

### 1-1. 事前準備
- rbenvのインストール（macOSならhomebrew経由）
- PostgreSQLのインストール
- ImageMagickのインストール（macOSならhomebrew経由）

## 2. 実行（ローカルバージョン）
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

## 3. 実行（Dockerバージョン）
事前準備、rubyのインストールは不要です。

### 3.1 レポジトリをクローン
```
git clone git@github.com:codeforjapan/decidim-cfj.git

```
### 3.2 masterブランチへチェックアウト
```
cd decidim-cfj
# masterブランチが最新
git checkout -b master origin/master
```

### 3.3 docker build
```
docker-compose build
```

### 3.4 言語の設定
```
# default_localeを`:en`にセットする
vim config/initializers/decidim.rb
# before
config.default_locale = :ja
# after
config.default_locale = :en
```

### 3.5 DB作成からシードまで
```
docker-compose run --rm app ./bin/rails db:create db:migrate
docker-compose run --rm app ./bin/rails db:seed
```

### 3.6 サーバー起動
```
docker-compose up -d
```
### 3.7 お疲れさまでした
http://localhost:3000 にアクセス

## 4. テスト用アカウント情報

テストデータとして用意されているアカウントです。
※ いずれもパスワードは`decidim123456`です

* 管理画面 (http://localhost:3000/system)
  * system@example.org
* サービス画面 (http://localhost:3000/users/sign_in?locale=ja)
  * admin@example.org （組織管理者）
  * user@example.org （通常ユーザ）

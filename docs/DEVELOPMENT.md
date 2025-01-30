# 開発者向け情報

[AWS環境へのデプロイ方法](./DEPLOYMENT.md)

## 1. 環境構築
Dockerで環境を構築する際は、1.環境構築と2. 実行（ローカルバージョン）は不要です。
直接、3. 実行（Dockerバージョン）から開始してください。

| アプリケーション名                                 | バージョン  |
|-------------------------------------------|--------|
| [Ruby](https://www.ruby-lang.org/ja/)     | 3.1.1  |
| [Bundler](https://bundler.io/)            | 2.4.21 |
| [PostgreSQL](https://www.postgresql.org/) | 12     |

### 1-1. 事前準備
- rbenvのインストール（macOSならhomebrew経由）
- PostgreSQLのインストール
- ImageMagickのインストール（macOSならhomebrew経由）

## 2. 実行（ローカルバージョン）
### 2.1 Rubyのインストール
```
rbenv install 3.1.1
```
### 2.2 リポジトリをクローン
```
git clone git@github.com:codeforjapan/decidim-cfj.git
```

### 2.3 bundlerのインストール

通常、Ruby 3.1.1ではbundler 2.3.7が標準でインストールされているはずですが、何かしらの事情でインストールされていない場合は改めてインストールしてください。

```
gem install bundler:2.3.7
```

### 2.4 DBのユーザーとパスワードの設定
```
export DATABASE_USERNAME=<yourname>
export DATABASE_PASSWORD=<yourpassword>
```

なお、DBのhost、port、DB名も設定したい場合は、以下のように環境変数を指定します。

```
export DATABASE_HOST=<yourhost>
export DATABASE_PORT=<yourport>
export DATABASE_DBNAME_DEV=<yourdbname>
```

### 2.5 bundle install
```
bundle install
```
### 2.6 DB作成からシードまで
```
bin/rails db:create db:migrate
bin/rails db:seed
```
### 2.7 サーバー起動
bin/rails s

### 2.8 お疲れさまでした
http://localhost:3000 にアクセス

## 3. 実行（Dockerバージョン）
事前準備、rubyのインストールは不要です。

### 3.1 リポジトリをクローン
```
git clone git@github.com:codeforjapan/decidim-cfj.git
```

### 3.2 docker build
```
docker compose build
```

### 3.3 DB作成からシードまで
```
docker compose run --rm app rails db:create db:migrate
docker compose run --rm app rails db:seed
```

`db:seed`でエラーが起きた場合、ダミーのデータ作成に失敗している可能性があります。以下を実行し、DBを再作成してみてください。

```
docker compose run --rm app rails db:reset
```

### 3.4 サーバー起動
```
docker compose up -d
```
### 3.5 お疲れさまでした
http://localhost:3000 にアクセス

## 4. テスト用アカウント情報

テストデータとして用意されているアカウントです。
※ いずれもパスワードは`decidim123456789`です

* 管理画面 (http://localhost:3000/system)
  * system@example.org
* サービス画面 (http://localhost:3000/users/sign_in?locale=ja)
  * admin@example.org （組織管理者）
  * user@example.org （通常ユーザ）

## 5. キャッシュとRedisについて

Railsのキャッシュはproduction環境ではRedis Cache Store(`ActiveSupport::Cache::RedisCacheStore`)を使うようになっています。

Redisの設定は環境変数 `REDIS_CACHE_URL` を使用しています。

development環境でのRailsの標準機能として、キャッシュのオン・オフをトグルで制御できます。オン・オフを切り替えたい場合、以下のコマンドを実行してください。

```console
# dockerを使っている場合
docker compose run app rails dev:cache

# localで動かしている場合
bin/rails dev:cache
```

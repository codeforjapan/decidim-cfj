# CfJ Decidim AWS への Install（Beanstalk 編）

## 1. Install AWS tools and setup user

[こちらの手順書](https://platoniq.github.io/decidim-install/decidim-aws/)の手順2を実施

## 2. Get Decidim source code

```bash
git clone https://github.com/codeforjapan/decidim-cfj.git
```

## 3. Bundle install

Ruby 環境はインストール済とする(ruby 2.6.6p146)

```bash
cd decidim-cfj
bundle install
```

## 4. Elastic Beanstalk に 環境をセットアップする

[https://platoniq.github.io/decidim-install/decidim-aws/] 手順書の手順3に従って環境を作る

eb create を実施

```bash
eb create production
```

最後エラーで終わるがOK

## 4. Secret Key Base を設定

```bash
eb setenv SECRET_KEY_BASE=$(bin/rails secret)
```

## 5. Postgres データベースを作成する

EB コンソールの該当環境から、Configuration を選択、Database を選択し、Edit をする

必要な設定を行い、DBを立ち上げる

その後`eb deploy`を実行

## 6. Healthcheck の条件を変更

`/` が301を返すので、一旦 301 でもOKにする

Elastic Beanstalk の Configuration 画面で、Health Check を選び、Process の条件を 80 から 301 にする

![img](https://i.imgur.com/VNZDQxA.png)
![img2](https://i.imgur.com/j595JQF.png)

## 7. CNAME 設定とSSL設定

Elastic Beanstalk のインスタンスをAレコードとして割り当てる

ロードバランサの設定をする（手順[6.2 Configure SSL](https://platoniq.github.io/decidim-install/decidim-aws/#62-configure-ssl)）

## 8. 最初のユーザを作る

[6.3 Create the first admin user](https://platoniq.github.io/decidim-install/decidim-aws/#63-create-the-first-admin-user)
に従う(root で)

## 9. SES の設定をする

[6.4 Setup email](https://platoniq.github.io/decidim-install/decidim-aws/#64-setup-email)

## 10. REDIS の設定をする

[6.5 Configure the job system with Sidekiq and Redis](https://platoniq.github.io/decidim-install/decidim-aws/#65-configure-the-job-system-with-sidekiq-and-redis)

## 11. S3 の設定をする

[6.6 File storage](https://platoniq.github.io/decidim-install/decidim-aws/#66-file-storage)

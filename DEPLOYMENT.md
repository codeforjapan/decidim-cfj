# ※GUIでElastic Beanstalkの設定をいじらないでください。デプロイで戻ります。

Elastic Beanstalkの設定はコードで管理されています。

インスタンスタイプやオートスケールの設定が違うため、stagingとproductionで一部ファイルが別です。それ以外の共通の設定は同じファイルを使っているので気を付けて下さい。

共通: [deployments/.ebextensions](deployments/.ebextensions)

staging: [deployments/staging](deployments/staging)
production: [deployments/production](deployments/production)

デプロイの際に上記の設定ファイルを元にデプロイが実行されます。コードでの設定がある場合、インフラも含め反映されます。

急ぎで、GUIで変更することはあると思います。しかし、GUIだけ変更してソースコードを変更しないと、デプロイの際に戻って事故の原因になります。なので、ソースコードに反映してください。

GUIの設定とコードの書き方は、[公式](https://docs.aws.amazon.com/ja_jp/elasticbeanstalk/latest/dg/command-options-general.html#command-options-general-elasticbeanstalkapplicationenvironment)を参考にしてください。

環境変数は環境別に設定する値だけ、[deployments/production/00_env_options.config](deployments/production/00_env_options.config) or [deployments/staging/00_env_options.config](deployments/staging/00_env_options.config)に記載して下さい。

秘密鍵などのSSM経由で参照される値は、デプロイ時に動的に展開されます。

```
{{resolve:ssm:ssmのパラメータの名前:バージョン}}
```

https://docs.aws.amazon.com/ja_jp/AWSCloudFormation/latest/UserGuide/dynamic-references.html

# GitHubからデプロイ

ワークフローの設定：[.github/workflows/deploy.yml](.github/workflows/deploy.yml)
デプロイの基本設定: [./deployments/](./deployments/)

1. ECRにログイン
1. Dockerコンテナをbuild
1. short commit hashを含む環境ごとのタグで、ECRにDockerイメージをpush
1. elastic beanstalkに該当のイメージを指定してデプロイ

Dockerイメージのタグ例: staging-dfasfste

```
[デプロイされる環境名]-[commit-hash]
```

## GitHubに必要な環境変数

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_ECR_REPO_NAME

## デプロイ手順

### production

切り戻しを早くするため、masterマージの際、Dockerイメージは毎回buildします。

パイプラインが通ったのを確認後、git上でデプロイしたいコミットに、v○○とタグを打ちます。
タグはvから始まる必要があります。すぐにeb deployが実行されます。

例: v1.0.0

### staging

developブランチにpushすると自動でデプロイされます。

## 切り戻し

### production

普通にデプロイするのと同様に戻したい先commitに対してタグを打ちます。
バグの場合、バグが発生したcommitの1つ前のcommitにたいしてタグを打ちます。

コンテナイメージはbuild済みなので、すぐにeb deployが実行されます。

### staging

revetしてdevelopブランチにpushしてください。

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

1. [docker-compose.yml](deployments/docker-compose.yml)で`{RepositoryName}`をデプロイしたいECRのイメージパスに修正。
1. [docker-compose.yml](deployments/docker-compose.yml)で`{EBEnvironment}}`をデプロイする環境名に修正。
1. 作成したい環境の設定をコピー。

[deployments/.elasticbeanstalk/config.yml](deployments/.elasticbeanstalk/config.yml)に設定があるので、基本的に何も聞かれないはずです。


```bash
cd deployments

# production
cp production/*.config .ebextensions/
# staging(台数とかログの保持期間が小さい)
cp staging/*.config .ebextensions/

eb create production --process
```

最後エラーで終わるがOK

## 4. Secret Key Base を設定

```bash
eb setenv SECRET_KEY_BASE=$(bin/rails secret)
```

## 5. Postgres データベースを作成する

必要な設定を行い、DBを立ち上げる

その後`eb deploy`を実行

## 6. CNAME 設定とSSL設定

Elastic Beanstalk のインスタンスをAレコードとして割り当てる

ロードバランサの設定をする（手順[6.2 Configure SSL](https://platoniq.github.io/decidim-install/decidim-aws/#62-configure-ssl)）

## 7. 最初のユーザを作る

[6.3 Create the first admin user](https://platoniq.github.io/decidim-install/decidim-aws/#63-create-the-first-admin-user)
に従う(root で)

## 8. SES の設定をする

[6.4 Setup email](https://platoniq.github.io/decidim-install/decidim-aws/#64-setup-email)

## 9. REDIS の設定をする

[6.5 Configure the job system with Sidekiq and Redis](https://platoniq.github.io/decidim-install/decidim-aws/#65-configure-the-job-system-with-sidekiq-and-redis)

sidekiqの設定をする必要はありません。dockerでデプロイされています。

stagingはcloud formationで作成しています。

[.cloudformation/elastic_cache.yml](.cloudformation/elastic_cache.yml)

## 10. S3 の設定をする

[6.6 File storage](https://platoniq.github.io/decidim-install/decidim-aws/#66-file-storage)

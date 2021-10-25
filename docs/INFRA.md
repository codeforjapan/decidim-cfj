# Cloud Formation の使い方

AWS の code as a infrastructureサービスCloud Formationで、インフラストラクチャを構築しています。

コードに落とすことで、レビューやバージョン管理が可能。またAWSコンソール上で、手動での変更検知などAWSに最適化されています。

これにより、本番とstagingの環境を簡単に揃えられます。

テンプレートファイルは、[.cloudformation](/.cloudformation)にまとめます。1テンプレートに多くのリソースを含むと、変更が大きくなるので分割して作成してください。


# 実行順

Cloud Front とWAFには依存関係があるので、下記の順で作成することを勧めます。

1. Kinesis firehose For WAF log
1. WAF Web ACL
1. Cloud Front

## VPC & Subnets

下記を参考に作成しています。VPC 1つ、public Subnet 3です。
https://github.com/awsdocs/elastic-beanstalk-samples/blob/main/cfn-templates/vpc-public.yaml

### Template file

[.cloudformation/vpc_subnets.yml](/.cloudformation/vpc_subnets.yml)

ログ出力用のs3バケットも作成してます。

### Stack Name

- staging-decidim-app-cloud-front
- production-decidim-app-cloud-front

## Redis

シンプルに本体を作成するだけです。サブネットグループ等は現状手動作成となります。

### Template file

[.cloudformation/elastic_cache.yml](/.cloudformation/elastic_cache.yml)

### Stack Name

- staging-decidim-redis

## Cloud Front

キャッシュポリシーとクラウドフロント本体を作成します。

### Template file

[.cloudformation/cloud_front.yml](/.cloudformation/cloud_front.yml)

### Stack Name

- staging-decidim-app-cloud-front
- production-decidim-app-cloud-front

## WAF

Cloud frontに合わせてus-east-1にあります。

### Template file

[.cloudformation/waf.yml](/.cloudformation/waf.yml)

### Stack Name

- staging-decidim-waf
- production-decidim-waf

## WAF

Cloud frontに合わせてus-east-1にあります。

### Template file

[.cloudformation/waf_kinesis_log.yml](/.cloudformation/waf_kinesis_log.yml)

### Stack Name

- staging-decidim-kinesis-waf-log
- production-decidim-kinesis-waf-log

## ECR

staging用と本番は同じリポジトリです。Dockerイメージのタグで区別します。

### Template file

[.cloudformation/ecr.yml](/.cloudformation/ecr.yml)

### Stack Name

- decidim-cfj-ecr-repository

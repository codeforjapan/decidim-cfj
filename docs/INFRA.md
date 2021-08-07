# Cloud Formation の使い方

AWS の code as a infrastructureサービスCloud Formationで、インフラストラクチャを構築しています。

コードに落とすとこで、レビューやバージョン管理が可能。またAWSコンソール上で、手動での変更検知などAWSに最適化されています。

これにより、本番とstagingの環境を簡単に揃えられます。

テンプレートファイルは、[.cloudformation](/.cloudformation)にまとめます。1テンプレートに多くのリソースを含むと、変更が大きくなるので分割して作成してください。

## VPC & Subnets

下記を参考に作成しています。VPC 1つ、public Subnet 3です。
https://github.com/awsdocs/elastic-beanstalk-samples/blob/main/cfn-templates/vpc-public.yaml

### template file

[.cloudformation/vpc_subnets.yml](/.cloudformation/vpc_subnets.yml)

### Stack Name

- staging-decidim-app-cloud-front

## redis

シンプルに本体を作成するだけです。サブネットグループ等は現状手動作成となります。

### template file

[.cloudformation/elastic_cache.yml](/.cloudformation/elastic_cache.yml)

### Stack Name

- staging-decidim-redis

## cloud Front

キャッシュポリシーとクラウドフロント本体を作成します。

### template file

[.cloudformation/cloud_front.yml](/.cloudformation/cloud_front.yml)

### Stack Name

- staging-decidim-app-cloud-front

## ECR

staging用と本番は同じレポジトリです。Dockerイメージのタグで区別します。

### template file

[.cloudformation/ecr.yml](/.cloudformation/ecr.yml)

### Stack Name

- decidim-cfj-ecr-repository

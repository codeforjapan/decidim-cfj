# アカウント一括登録（CSV直接登録）

招待メールを送らずに、CSVから「メール確認済み・利用規約同意済み」のログイン可能なアカウントを一括作成する仕組みです。
事前に参加者が確定していて、運営側で認証情報を配布する運用（研修・ワークショップなど）を想定しています。

## 1. 概要

| 項目 | 現行（招待メール方式） | CSV一括・直接登録方式 |
|------|------------------------|------------------------|
| メール送信 | 参加者ごとに招待メールを送信 | 送信なし |
| パスワード | 本人がリンクから設定 | 自動生成（後から本人が変更可） |
| 規約同意 | 本人が画面で操作 | 自動でONにする |
| ニュースレター受信 | 本人が画面で操作 | OFFのまま（各自が設定画面でONにする） |
| ログインまで | 招待リンクの操作・本人設定が必要 | 配布した認証情報で即ログイン可 |
| 内部実装 | `devise_invitable` の `invite!` / `accept_invitation!` | `Decidim::User` を直接作成し `skip_confirmation!` |

構成ファイル

| ファイル | 役割 |
|----------|------|
| `app/services/decidim/bulk_user_importer.rb` | 一括登録のコアロジック |
| `lib/tasks/bulk_users.rake` | CSVを読み込んで実行する rake タスク |

## 2. 使い方

### 2.1 事前準備: 組織の利用規約バージョン

利用規約の同意は `tos_agreement` と `accepted_tos_version` の**両方**で判定され、`accepted_tos_version` は組織の `tos_version` との日時比較で評価されます。
組織の `tos_version` が未設定のままだと、作成した全ユーザーが「規約未同意」扱いになります。

管理画面から利用規約を一度保存するか、次のように設定してください。未設定の場合、rake タスクは処理を行わず中断します。

```bash
bundle exec rails runner '
  org = Decidim::Organization.first
  org.update!(tos_version: Time.current) if org.tos_version.blank?
  puts "org=#{org.id} host=#{org.host} tos_version=#{org.tos_version}"
'
```

### 2.2 入力CSV

ヘッダ行の `email` 列は必須です。任意で `name` / `nickname` / `password` 列を追加でき、空の場合は自動生成されます。

```csv
email,name
taro.yamada@example.com,山田 太郎
hanako@example.com,
```

### 2.3 実行

組織の指定は既存の rake タスクと同じく `DECIDIM_ORGANIZATION_ID` または `DECIDIM_ORGANIZATION_NAME` で行います。

```bash
DECIDIM_ORGANIZATION_ID=1 bundle exec rails bulk_users:import \
  IN=tmp/bulk/emails.csv OUT=tmp/bulk/created.csv
```

| 環境変数 | 必須 | 内容 |
|----------|------|------|
| `DECIDIM_ORGANIZATION_ID` / `DECIDIM_ORGANIZATION_NAME` | どちらか必須 | 対象組織 |
| `IN` | 必須 | 入力CSVのパス |
| `OUT` | 任意 | 出力CSVのパス（既定 `created_users.csv`） |

標準出力には `created=2 skipped=0 failed=0` の形式で件数が出ます。失敗した行は `FAILED <email>: <理由>` として標準エラーに列挙されます。

入出力のCSVは `tmp/` 配下に置いてください（`.gitignore` 済みのため、生成パスワード入りCSVの誤コミットを防げます）。

### 2.4 出力CSV

| 列 | 内容 |
|----|------|
| `email` | 入力のメールアドレス（小文字化・前後の空白除去済み） |
| `nickname` | 作成されたニックネーム |
| `name` | 作成された表示名 |
| `password` | 生成された平文パスワード（`status=created` の場合のみ） |
| `status` | `created` / `skipped` / `failed` |
| `error` | `skipped` / `failed` の理由（`blank email`、`already exists`、バリデーションメッセージ） |

`status` の意味は次のとおりです。

- `created`: 作成に成功
- `skipped`: `email` が空（`blank email`）、または同じ組織に同じメールアドレスが既に存在する（`already exists`）
- `failed`: バリデーションエラー。1行の失敗が他の行の処理を止めることはありません

同じメールアドレスは `skipped` になるため、同じCSVを再実行しても重複作成されません（冪等）。

## 3. 実装上の注意

### 3.1 ログインはメールアドレス

Decidim のログインは**メールアドレス + パスワード**です。`nickname`（@ハンドル）はプロフィール用の表示IDであり、ログインIDではありません。
参加者には「メールアドレス」と「パスワード」を配布してください。

### 3.2 ニックネームの自動生成

`nickname` はメールアドレスのローカル部から `Decidim::User.nicknamize` で生成します。記号は `_` に正規化され、20文字に切り詰められ、既存と衝突する場合は `john_doe`, `john_doe_2` のように連番が付きます。
連番による一意化を効かせるため、一括作成は全体を1つのトランザクションで囲まず、行ごとに保存しています。

### 3.3 パスワードの制約

自動生成されるパスワードは、Decidim の `PasswordValidator` の制約を満たすようになっています。

- 10文字以上・256文字以下
- ユニークな文字が5種類以上
- 表示名・ニックネーム・メールのローカル部・メールドメインや組織ホストのラベル（既定で4文字以上）を含まない
- よくあるパスワード・拒否リストに該当しない

CSVの `password` 列で明示的に指定した場合はその値がそのまま使われるため、上記を満たさない値を渡すとその行は `failed` になります。

### 3.4 メールは送信されない

`invite!` を呼ばず、`skip_confirmation!` で `confirmed_at` をセットしているため、招待メールも確認メールも送信されません。
`managed` は `false`（通常ユーザー）のままにしています。`true` にするとログインできなくなるため変更しないでください。

### 3.5 ニュースレター受信は設定しない

`newsletter_notifications_at` は設定せず、OFF（`nil`）のままにしています。強制的にONにする必要性がそもそもないためです。
受信を希望する参加者には、ログイン後のアカウント設定（通知設定）から各自でONにしてもらってください。

## 4. セキュリティ上の注意

生成した平文パスワードをCSVで配布・保管する運用には漏洩リスクがあります。

- 出力CSVは配布後すみやかに削除し、共有時は経路にも注意してください
- 参加者には初回ログイン後のパスワード変更を促してください
- 検証用に作成したテストユーザーを本番環境に混入させないでください

### より安全な代替手順

生成パスワードを**配布しない**運用も可能です。アカウントだけを作成し（＝誰も知らないランダムなパスワードのまま）、参加者には `/users/password/new`「パスワードをお忘れの方」から各自パスワードを設定してもらいます。
作成されたアカウントはメール確認済みのため、リセットメールは正常に届きます。出力CSVの `password` 列を使わずに破棄するだけで切り替えられます。

## 5. 既知の制約

- 管理画面からCSVをアップロードするUIは未実装です（別PRで対応予定）
- 組織をまたいだ一括作成には対応していません。組織ごとに実行してください
- 既存ユーザーの属性更新は行いません（既存メールは常に `skipped`）

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
| 通知メール（ダイジェスト） | 既定のまま（`daily`） | OFF（`none`）にする（各自が設定画面で変更可） |
| ログインまで | 招待リンクの操作・本人設定が必要 | 配布した認証情報で即ログイン可 |
| 内部実装 | `devise_invitable` の `invite!` / `accept_invitation!` | `Decidim::User` を直接作成し `skip_confirmation!` |

構成ファイル

| ファイル | 役割 |
|----------|------|
| `app/services/decidim/bulk_user_importer.rb` | 一括登録のコアロジック |
| `lib/tasks/bulk_users.rake` | CSVを読み込んで実行する rake タスク |
| `app/controllers/decidim/admin/bulk_user_imports_controller.rb` | 管理画面のCSVアップロード画面 |
| `app/permissions/decidim/bulk_user_import_permissions.rb` | 管理画面の権限（組織admin限定） |
| `app/views/decidim/admin/bulk_user_imports/new.html.erb` | アップロードフォーム |
| `config/initializers/bulk_user_import.rb` | ルーティング・アイコン・管理メニューの登録 |
| `config/initializers/admin_log_organization_presenter_override.rb` | `/admin/logs` での一括登録の表示 |
| `config/locales/bulk_user_import.{ja,en}.yml` | 画面文言 |

実行方法は2つあり、どちらも同じ `Decidim::BulkUserImporter` を呼びます。

| | 管理画面 | rake タスク |
|---|----------|-------------|
| 使える人 | 組織の管理者 | サーバのシェル権限を持つ人 |
| 件数の上限 | 500行 / 1MB（同期処理のため） | なし |
| 出力CSV | ブラウザにダウンロード | `OUT=` で指定したパス |
| 実行記録 | `/admin/logs` に残る | 残らない（標準出力のみ） |

## 2. 使い方

### 2.1 事前準備: 組織の利用規約バージョン

利用規約の同意は `tos_agreement` と `accepted_tos_version` の**両方**で判定され、`accepted_tos_version` は組織の `tos_version` との日時比較で評価されます。
組織の `tos_version` が未設定のままだと、作成した全ユーザーが「規約未同意」扱いになります。

管理画面から利用規約を一度保存するか、次のように設定してください。未設定の場合、rake タスクは処理を行わず中断し、管理画面はエラーを表示します。

```bash
bundle exec rails runner '
  org = Decidim::Organization.first
  org.update!(tos_version: Time.current) if org.tos_version.blank?
  puts "org=#{org.id} host=#{org.host} tos_version=#{org.tos_version}"
'
```

### 2.2 入力CSV

ヘッダ行の `email` 列は必須です。任意で `name` / `nickname` / `password` 列を追加でき、空の場合は自動生成されます。

列名は完全一致で照合します。`Email` のように大文字が混ざっていたり、ヘッダ行が無かったりする場合は、処理を行わずに中断します（管理画面でもエラーを表示します）。

```csv
email,name
taro.yamada@example.com,山田 太郎
hanako@example.com,
```

文字コードは UTF-8 です。Excel で保存した BOM 付き UTF-8 のCSVもそのまま渡せます（`encoding: "bom|utf-8"` で読み込むため、BOM は除去されます）。

出力CSVには BOM を付けています。Excel でそのまま開いても日本語（`name` 列、発行タスクの `furigana` 列）が文字化けしません。

### 2.3 実行: 管理画面

管理画面の「参加者」→「アカウント一括登録」を開き、CSVを選んで「一括登録する」を押します。
処理が終わると、結果CSV（`created_users_<timestamp>.csv`）のダウンロードが始まります。画面は遷移しません。

- 使えるのは**その組織の管理者のみ**です。作成されるユーザーは常にログイン中の組織に属します
- 同期処理のため、**1回あたり 500行・1MB** が上限です。超える場合はCSVを分割するか、rake タスクを使ってください
- 誰が・いつ・何件作成したかは `Decidim::ActionLogger` で記録され、`/admin/logs` から確認できます
- ファイル未添付・拡張子が `.csv` でない・CSVが壊れている・`email` 列が無い・行数超過の場合は、画面上にエラーが表示されます（登録は行われません）

ダウンロードされるCSVには**平文パスワードが含まれます**。配布後はすみやかに削除してください。

### 2.4 実行: rake タスク

組織の指定は既存の rake タスクと同じく `DECIDIM_ORGANIZATION_ID` または `DECIDIM_ORGANIZATION_NAME` で行います。

```bash
DECIDIM_ORGANIZATION_ID=1 bundle exec rails bulk_users:import \
  IN=tmp/bulk/emails.csv OUT=tmp/bulk/created.csv
```

| 環境変数 | 必須 | 内容 |
|----------|------|------|
| `DECIDIM_ORGANIZATION_ID` / `DECIDIM_ORGANIZATION_NAME` | どちらか必須 | 対象組織 |
| `IN` | 必須 | 入力CSVのパス |
| `OUT` | 任意 | 出力CSVのパス（既定 `tmp/bulk_users/created_users_<日時>.csv`）。既存ファイルがある場合は上書きせず中断します |

標準出力には `created=2 skipped=0 failed=0` の形式で件数が出ます。失敗した行は `FAILED <email>: <理由>` として標準エラーに列挙されます。

出力CSVは平文パスワードを含むため、パーミッション `0600` で作成されます。既定の出力先は `tmp/` 配下（`.gitignore` 済み）で、`created_users*.csv` というファイル名もどこにあっても ignore されます。入力CSVも `tmp/` 配下に置いてください。

### 2.5 出力CSV

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
- `failed`: バリデーションエラーなど。想定外のエラーもその行だけ `failed` として記録され、1行の失敗が他の行の処理を止めることはありません

出力CSVは1行処理するたびに書き出してフラッシュされます。途中でプロセスが落ちても、そこまでに作成したユーザーの認証情報はCSVに残ります（残らないと、DBにはユーザーがいるのにパスワードが誰にもわからない状態になるため）。

同じメールアドレスは `skipped` になるため、同じCSVを再実行しても重複作成されません（冪等）。`failed` になった行を修正して再実行すれば、成功済みの行は `skipped` されて未処理の行だけが作成されます。

再実行時に同じ `OUT` を指定しても、既存ファイルは上書きせず中断します。1回目に発行したパスワードは出力CSVにしか残らないためです（`skipped` の行は `password` 列が空になるので、上書きすると発行済みパスワードが失われます）。再実行の出力は別のファイルに書いてください。

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

「よくあるパスワード」（`Decidim::CommonPasswords`）と拒否リスト（`Decidim.denied_passwords`）は生成時にも照合し、一致した候補は引き直します。引き直しは有限回（1,000回）で打ち切られ、超えた場合はその行が `failed` になります。

生成に使う文字と長さは `Decidim::BulkUserImporter.new` の `password_length:` / `password_charset:` で変更できます。既定は英大文字・小文字・数字の16文字です。`password_length` は `PasswordValidator` の最小長（10文字）未満を指定できません。

CSVの `password` 列で明示的に指定した場合はその値がそのまま使われるため、上記を満たさない値を渡すとその行は `failed` になります。

### 3.4 メールは送信されない

`invite!` を呼ばず、`skip_confirmation!` で `confirmed_at` をセットしているため、招待メールも確認メールも送信されません。
`managed` は `false`（通常ユーザー）のままにしています。`true` にするとログインできなくなるため変更しないでください。

### 3.5 ニュースレター受信は設定しない

`newsletter_notifications_at` は設定せず、OFF（`nil`）のままにしています。強制的にONにする必要性がそもそもないためです。
受信を希望する参加者には、ログイン後のアカウント設定（通知設定）から各自でONにしてもらってください。

### 3.6 通知メール（ダイジェスト）はOFFにする

`notifications_sending_frequency` を `"none"` に設定します。Decidim の既定は `daily` で、通知が溜まり始めるとダイジェストメールが毎日送信されます。受信できないアドレスで登録する運用ではこれがバウンスし続け、メール基盤の送信レピュテーションを損なうためです。作成直後は通知が無いため送信されず、参加者の活動が始まってから顕在化する点に注意してください。
受信を希望する参加者には、ログイン後のアカウント設定（通知設定）から各自で変更してもらってください。

## 4. セキュリティ上の注意

生成した平文パスワードをCSVで配布・保管する運用には漏洩リスクがあります。

- 出力CSVは配布後すみやかに削除し、共有時は経路にも注意してください
- 参加者には初回ログイン後のパスワード変更を促してください
- 検証用に作成したテストユーザーを本番環境に混入させないでください

### より安全な代替手順

生成パスワードを**配布しない**運用も可能です。アカウントだけを作成し（＝誰も知らないランダムなパスワードのまま）、参加者には `/users/password/new`「パスワードをお忘れの方」から各自パスワードを設定してもらいます。
作成されたアカウントはメール確認済みのため、リセットメールは正常に届きます。出力CSVの `password` 列を使わずに破棄するだけで切り替えられます。

## 5. 既知の制約

- 管理画面からの実行は同期処理のため、1回あたり 500行・1MB が上限です（大量件数は rake タスクを使うか、ActiveJob 化を検討してください）
- 組織をまたいだ一括作成には対応していません。組織ごとに実行してください
- 既存ユーザーの属性更新は行いません（既存メールは常に `skipped`）
- `available_authorizations` に `user_extension` を含む組織では、作成したユーザーはログイン後に拡張属性（氏名・住所など）の入力を求められ、入力を終えるまで各ページから `/account` へリダイレクトされます。これは既存の招待フローで作成したユーザーと同じ挙動です（招待受諾フローも拡張属性を作成しないため）
- ウェルカム通知（`decidim.events.core.welcome_notification`）は発火しません。`skip_confirmation!` は Devise の `after_confirmation` コールバックを通らないためです。招待フローと同じ挙動で、自己登録フローとの差異です

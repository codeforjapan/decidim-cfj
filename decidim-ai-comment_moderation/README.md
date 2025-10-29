# Decidim::Ai::CommentModeration

OpenAI Chat APIを活用したAIコメントモデレーションモジュールです。
スパムや暴力的・挑発的なコメントを自動検出し、DecidimのReport機能を使いAdmin宛に報告します。

## 概要

このモジュールは、Decidimの組み込みモデレーションワークフローと統合し、スパム、暴力的、挑発的なコメントを自動的に検出して通報します。
OpenAI Chat APIを使用してコンテンツを分析し、シンプルな設定で動作します。

## 機能

- 自動検出: スパムと不適切なコンテンツ（暴力的・挑発的・ヘイト的）の自動検出
- 信頼度ベースの判定: 設定可能な信頼度しきい値による柔軟なモデレーション
- 自動非表示: 非常に高い信頼度のコメントを自動的に非表示にする機能（オプション）
- Decidimの既存機能と連携: 標準の通報システムと完全に統合

## アーキテクチャ

### 二層構造

#### Layer 1: AI分析レコード
- コメントの作成通知をsubscribeし、AIによる分析を行い、結果を`Decidim::Ai::CommentModeration::CommentModeration`に記録
- 保存内容: OpenAI Chat APIによる分析結果（カテゴリ、信頼度、理由）

#### Layer 2: Decidim通報
- 分析結果により問題があるコメントであれば、Admin宛の通知を行う
- 通知には`Decidim::CreateReport`を利用

### AIカテゴリマッピング

OpenAI Chat APIによる分析カテゴリを、シンプルなDecidim通報理由にマッピングします：

| AIカテゴリ | Decidim通報理由 | 説明 |
|-----------|---------------|-----|
| offensive | `offensive` | 暴力的、挑発的、ハラスメント、ヘイトスピーチなど |
| spam | `spam` | スパム、広告、宣伝、無関係なリンクなど |
| inappropriate | `does_not_belong` | 性的なコンテンツ、違法な内容など |

## インストール

### 1. Gemfileに追加

アプリケーションのGemfileに以下の行を追加してください：

```ruby
gem "decidim-ai-comment_moderation", path: "decidim-ai-comment_moderation"
```

### 2. Bundleインストール

```bash
bundle install
```

### 3. マイグレーション実行

```bash
rails decidim_ai_comment_moderation:install:migrations
rails db:migrate
```

## 設定

### initializerによる設定

`config/initializers/decidim_ai_comment_moderation.rb`を作成し、以下のように設定します。

```ruby
# frozen_string_literal: true

Decidim::Ai::CommentModeration.configure do |config|
  # OpenAI API キー（必須）
  config.openai_api_key = ENV["OPENAI_API_KEY"]

  # AIモデレーションを有効にする組織のホスト名（配列、デフォルト: []）
  config.enabled_hosts = ["example.org", "demo.example.org"]

  # 通報を作成する信頼度しきい値（0.0〜1.0、デフォルト: 0.8）
  config.confidence_threshold = 0.8

  # コメントを自動非表示にする信頼度しきい値（0.0〜1.0、デフォルト: nil）
  # nilを設定すると自動非表示機能は無効になります
  config.auto_hide_threshold = 0.95

  # オプション: AIユーザーのメールアドレス（全組織共通、デフォルト: nil）
  # 設定しない場合は組織ごとに ai-moderation@{organization.host} が使用されます
  config.ai_user_email = "ai-moderation@example.org"

  # オプション: OpenAI Chat モデル（デフォルト: gpt-4o-mini）
  config.model = "gpt-4o-mini"
end
```

### 設定へのアクセス

設定値には以下の方法でアクセスできます：

```ruby
# モジュールレベルでアクセス
Decidim::Ai::CommentModeration.config.openai_api_key
Decidim::Ai::CommentModeration.config.enabled_hosts
Decidim::Ai::CommentModeration.config.confidence_threshold
Decidim::Ai::CommentModeration.config.auto_hide_threshold
Decidim::Ai::CommentModeration.config.ai_user_email
Decidim::Ai::CommentModeration.config.model

# ヘルパーメソッド
Decidim::Ai::CommentModeration.enabled_for?(organization)
```

### 設定例

```ruby
# 80%以上の信頼度で自動通報（推奨）
config.confidence_threshold = 0.8

# 95%以上の信頼度で自動非表示
config.auto_hide_threshold = 0.95

# より厳格に90%以上で通報
config.confidence_threshold = 0.9

# より寛容に70%以上で通報
config.confidence_threshold = 0.7

# 自動非表示機能を無効にする
config.auto_hide_threshold = nil

# 環境変数から値を読み込む
config.openai_api_key = ENV["OPENAI_API_KEY"]
config.enabled_hosts = ENV.fetch("HOSTS", "").split(",").map(&:strip)
config.confidence_threshold = ENV.fetch("THRESHOLD", "0.8").to_f
config.auto_hide_threshold = ENV.fetch("AUTO_HIDE_THRESHOLD", "").presence&.to_f
```

## 動作フロー

1. コメント作成: ユーザーが新しいコメントを投稿
2. イベント発行: Decidimが`decidim.comments.comment_created`イベントを発行
3. ジョブ自動実行: engine.rbのイベントサブスクライバーが`AnalyzeCommentJob`を自動的にエンキュー
4. AI分析: OpenAI Chat APIがコンテンツを分析
   - AIが3つのカテゴリ（spam、offensive、inappropriate）で判定
   - 信頼度スコア（0.0〜1.0）と判定理由を返す
5. レコード作成: AI分析結果が`CommentModeration`レコードに保存される
6. 判定ロジック:
   - フラグあり AND 信頼度 ≥ auto_hide_threshold → コメントを自動非表示（`config.auto_hide_threshold`が設定されている場合）
   - フラグあり AND 信頼度 ≥ confidence_threshold → Decidim通報を作成
   - フラグあり BUT 信頼度 < confidence_threshold → 監視用にログ記録
   - フラグなし → アクションなし

注意: 組織のホストが`config.enabled_hosts`に含まれていない場合、ジョブは実行されても分析をスキップします。

## AIシステムユーザー

システムは組織ごとに特別なAIユーザーを作成し、AI生成の通報を送信します：

- メールアドレス:
  - デフォルト: `ai-moderation@{organization.host}`（組織ごと）
  - カスタム: `DECIDIM_AI_USER_EMAIL`で全組織共通のメールアドレスを設定可能
- ニックネーム: `ai_moderator_{organization.id}`（組織ごとにユニーク）
- 管理ユーザー: ログインできず、メールを受信しない
- 用途: 通報作成のためにのみ内部で使用

## 使用方法

### 手動でジョブを実行（オプション）

既存のコメントを再分析したい場合や、手動で分析をトリガーしたい場合：

```ruby
# 特定のコメントを分析
Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_later(comment_id)

# または即座に実行
Decidim::Ai::CommentModeration::AnalyzeCommentJob.perform_now(comment_id)
```

### 分析結果の確認

```ruby
# Railsコンソールで
comment = Decidim::Comments::Comment.last
moderation = comment.ai_moderation

# フラグ状態をチェック
moderation.flagged?  # true/false

# 通報理由を取得
moderation.decidim_reason  # "spam", "offensive", "does_not_belong"

# 信頼度スコアを取得
moderation.confidence_score  # 0.0〜1.0

# フラグされたカテゴリを取得
moderation.flagged_categories  # ["offensive", "spam"]

# カテゴリ別の判定結果
moderation.spam?          # スパムかどうか
moderation.offensive?     # 攻撃的かどうか
moderation.inappropriate? # 不適切かどうか

# 深刻度を取得
moderation.severity  # "low", "medium", "high"

# モデレーションが必要かどうか
moderation.requires_moderation?  # true/false

# 完全な分析結果にアクセス
moderation.analysis_result  # JSONBフィールド
```

### ログの監視

モジュールはすべての分析結果を記録します。Railsログで`[AI Moderation]`を確認してください：

```
[AI Moderation] Comment #123 analyzed: Flagged: true, Decidim Reason: offensive, Confidence: 0.92
[AI Moderation] Flagged categories: harassment, violence
[AI Moderation] Report created successfully for comment #123
```

## データベーススキーマ

`decidim_ai_comment_moderations`テーブルの構造：

| フィールド | 型 | 説明 |
|---------|------|------|
| `commentable_type` | string | ポリモーフィック関連の型 |
| `commentable_id` | integer | コメントのID |
| `analysis_result` | jsonb | 完全なAI分析結果 |
| `confidence_score` | float | 信頼度スコア（0.0〜1.0） |
| `created_at` | datetime | 作成日時 |
| `updated_at` | datetime | 更新日時 |

### analysis_result構造

```json
{
  "flagged": true,
  "decidim_reason": "offensive",
  "confidence": 0.92,
  "severity": "high",
  "flagged_categories": ["offensive"],
  "categories": {
    "spam": false,
    "offensive": true,
    "inappropriate": false
  },
  "reason": "このコメントにはハラスメントや脅迫的な表現が含まれています。"
}
```

## テスト

```bash
# decidim-cfjディレクトリから実行

# すべてのテストを実行
bundle exec rspec decidim-ai-comment_moderation/spec/

# 特定のテストスイートを実行
bundle exec rspec decidim-ai-comment_moderation/spec/services/
bundle exec rspec decidim-ai-comment_moderation/spec/jobs/
bundle exec rspec decidim-ai-comment_moderation/spec/commands/
bundle exec rspec decidim-ai-comment_moderation/spec/models/
bundle exec rspec decidim-ai-comment_moderation/spec/system/
```

## トラブルシューティング

### APIキーが無効

```
[AI Moderation] AI Analysis failed: Incorrect API key provided
```

→ `OPENAI_API_KEY`が正しく設定されているか確認してください

### モデレーションが動作しない

1. 組織のホストが`config.enabled_hosts`に含まれているか確認
2. OpenAI APIキーが正しく設定されているか確認
3. マイグレーションが実行されているか確認: `rails db:migrate:status`
4. Railsログで`[AI Moderation]`を検索して詳細なエラーを確認

### しきい値の調整

- 誤検出が多い: しきい値を上げる（例: 0.9）
- 見逃しが多い: しきい値を下げる（例: 0.7）

## ライセンス

このモジュールは[AGPL-3.0ライセンス](https://opensource.org/licenses/AGPL-3.0)の条件の下でオープンソースとして利用可能です。

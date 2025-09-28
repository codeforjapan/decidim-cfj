# Decidim::Ai::CommentModeration

OpenAIを活用したAIコメントモデレーションモジュールです。

## 機能

- スパムと不適切なコンテンツの自動検出
- 信頼度に基づくモデレーション判定
- AI分析結果の詳細なログ記録
- 日本語と英語のサポート

## インストール

アプリケーションのGemfileに以下の行を追加してください：

```ruby
gem "decidim-ai-comment_moderation", path: "decidim-ai-comment_moderation"
```

その後、以下を実行してください：

```bash
$ bundle install
```

マイグレーションを実行します：

```bash
$ rails decidim_ai_comment_moderation:install:migrations
$ rails db:migrate
```

## 設定

`.env`ファイルに以下の環境変数を設定してください：

```bash
# 必須
OPENAI_API_KEY=sk-...

# オプション（デフォルト値あり）
DECIDIM_AI_MODERATION_ENABLED_HOSTS=decidim.exapmle.org,decidim.example.jp
DECIDIM_AI_MODERATION_MODEL=gpt-3.5-turbo
```

## 使用方法

インストールと設定が完了すると、モジュールは自動的に以下を実行します：

1. 新しいコメントの作成を監視
2. OpenAIに分析を依頼
3. 分析結果をデータベースに保存
4. モデレーターレビュー用に潜在的な問題をログに記録

### 分析結果の確認

```ruby
# Railsコンソールで
comment = Decidim::Comments::Comment.last
moderation = comment.ai_moderation

# スパムまたは不適切かをチェック
moderation.spam?
moderation.offensive?

# 信頼度スコアを取得
moderation.confidence_score

# 理由を取得
moderation.reasons
```

### ログの監視

モジュールはすべての分析結果をログに記録します。Railsログで`[AI Moderation]`を確認してください：

```
[AI Moderation] Comment #123 analyzed: Spam: true, Offensive: false, Confidence: 0.92, Severity: high
[AI Moderation] Reasons: advertisement, promotional links
```

## データベーススキーマ

モジュールは以下のフィールドを持つ`decidim_ai_comment_moderations`テーブルを作成します：

- `commentable_type`と`commentable_id`：コメントへのポリモーフィック関連
- `analysis_result`：完全なAI分析を含むJSONBフィールド
- `confidence_score`：AI信頼度を示す浮動小数点値（0.0-1.0）
- `created_at`と`updated_at`：タイムスタンプ

## AI分析レスポンス形式

AIは以下の形式で分析を返します：

```json
{
  "is_spam": boolean,
  "is_offensive": boolean,
  "confidence": 0.0-1.0,
  "reasons": ["理由1", "理由2"],
  "severity": "low|medium|high"
}
```

## 今後の機能拡張予定

- AIモデレーション確認用の管理画面
- 高信頼度違反の自動非表示機能
- 他のAIプロバイダー（Anthropicなど）のサポート
- AI精度向上のためのフィードバック機能
- Decidimの既存モデレーションシステムとの統合

## コントリビューション

バグレポートやプルリクエストは、GitHubのhttps://github.com/codeforjapan/decidim-cfj で歓迎しています。

## ライセンス

このモジュールは[AGPL-3.0ライセンス](https://opensource.org/licenses/AGPL-3.0)の条件の下でオープンソースとして利用可能です。

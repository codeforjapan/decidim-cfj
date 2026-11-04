# Decidim 0.30.9 → 0.31 アップグレード実行計画

> 実行方針: **専用ブランチ `upgrade/decidim-0.31` 上での更新**。cfj の実運用フローを採用 —
> **①外部の decidim 拡張 gem を全部コメントアウト → ②本体のみ 0.31 化して CHANGELOG/RELEASE_NOTES の更新手順を実行 → ③本体のみで起動確認 → ④コメントアウトした gem を1つずつ有効化&ポートして都度起動確認**。
> 本番(prd-v030 = 0.30.9)は Phase 9 まで無傷で、新環境で全検証してから**ブルーグリーン切替**(prd-v030 移行の踏襲)。
> 各 Phase は独立チャットで連続実行できるよう自己完結。Phase 間に**検証ゲート**。
> 一次情報: 会話内3エージェント調査 / `memory/project_decidim_031_upgrade_impact.md` / `decidim/` リポの `v0.31.1:RELEASE_NOTES.md`・`CHANGELOG.md`。

---

## Phase 0: 前提・許可API・アンチパターン(実行前に必読)

### プラットフォーム要件(0.30.9 → 0.31 実測差分)
| 項目 | 現状 | 0.31 目標 |
|---|---|---|
| Ruby | 3.3.4 | **3.3.11**(core `~> 3.3.0`、awesome 0.31 が 3.3.11 要求) |
| Rails | **7.0.10** | **7.2.2.2** |
| Node | 20.18.3 | **22.14.0** |
| shakapacker | 7.1.0 | **8.3.0**(major、本体が要求) |
| @decidim/* npm | ^0.30.9 | ^0.31.x |
> CLAUDE.md の「Rails 6.1 / Decidim 0.30.3」は古い。実体は Rails 7.0.10 / Decidim 0.30.9。

### 許可API / 正しい名前(0.31)
- 設定: `Rails.application.credentials` / `config_for` / `ENV`（**`Rails.application.secrets` 禁止=削除済み**）
- Forms: `UserResponsesSerializer#hash_for(response)` / `ResponseQuestionnaire`（**`UserAnswersSerializer`/`AnswerQuestionnaire` 禁止**）
- Surveys: `PublishResponsesController`（**`PublishAnswersController` 禁止**）
- omniauth: `trigger_omniauth_event(...)`（**`trigger_omniauth_registration` 禁止**）
- 役割: `Evaluator`（**`Valuator` 禁止**）/ OAuth scope: `profile`（**`public` 禁止**）

### アンチパターン
- `Rails.application.secrets.*` を残す → boot 失敗
- `Forms::Answer/AnswerChoice/AnswerOption/AnswerQuestionnaire`、`UserGroup`、Metrics、`Valuator` を参照(全削除/リネーム)
- 1つの `to_prepare` に複数パッチ同居(1 NameError で全滅)
- #850/#851/#852 を 0.30 クラス名のまま持ち込む → 0.31 版として作り直す
- HERE maps 設定 / `enable_proposal_linking` / hashtag フィールド参照(削除済み)

### ロールバック戦略(全 Phase 共通)
- コードは `upgrade/decidim-0.31` に隔離。main(0.30.9 稼働)は無傷。
- インフラは新スタック並走、本番は Phase 9 切替まで prd-v030。切替後も旧スタック保持で即戻し可。
- 破壊的マイグレーション(Answer→Response 等)は**本番 RDS スナップショット復元 DB** で先行リハーサル。

---

## Phase 1: ブランチ準備 + 外部拡張 gem を全部コメントアウト

**目的**: bundle を「decidim 本体のみ」で解決させ、コア更新を最小面積で検証できる状態にする。

### タスク
1. `git switch -c upgrade/decidim-0.31`
2. `Gemfile` で**外部 decidim 拡張 gem をコメントアウト**:
   - `decidim-decidim_awesome` / `decidim-term_customizer` / `decidim-navigation_maps` / `decidim-polis` / `decidim-broadlistening-view`
3. **それらを参照する配線も同時にコメントアウト**(未コメントだと boot 時 NameError):
   - `config/initializers/decidim_awesome.rb`・`decidim_awesome_patches.rb`
   - term_customizer / navigation_maps / polis / broadlistening-view の engine mount・initializer・seeds・メニュー登録
   - これらモジュールを使う view/component 参照(あれば一時的に無効化)
4. **判断**: 認証に必須な独自 gem(`decidim-user_extension`・`omniauth-line_login`・`omniauth-cityos-dcp`)は**残す**(Phase 3-4 の起動確認でログインが要るため)。ただし user_extension が boot を阻害する場合は一時コメントアウトして Phase 5 冒頭で最優先復帰。

### 検証ゲート
- `git grep -n` で、コメントアウトした gem の定数(`Decidim::DecidimAwesome` 等)を参照する**アクティブなコードが残っていない**。

---

## Phase 2: 本体のみバンプ(bundle/yarn を解決させる)

### タスク
1. `Gemfile`: `gem "decidim", "0.31.x"`、`decidim-conferences`/`decidim-ai` を `~> 0.31`。
2. `.ruby-version` → `3.3.11`。`Dockerfile`: `ruby:3.3.11-slim-bookworm` / `node:22.14.0-bookworm-slim`。
3. `config/application.rb`: **`load_defaults 6.1` → `7.2`**（RELEASE_NOTES §2.1）。
   ⚠️ **【訂正 2026-08-24】元は「7.0 → 7.2」と誤記しており、実ファイルの `6.1` と照合されず作業ごと未実施のまま残った。**
   単純な書き換えは危険（セッションが Redis の Rails.cache にあるため）。手順は `decidim-0.31-remaining-work.md` 付録A を参照。
4. `package.json`: `@decidim/*` を `^0.31`、`shakapacker` を `~8.3.0`、`engines.node >=22`。
5. `bundle install` / `yarn install` を解決させる(**本体のみなので拡張 gem の 0.31 未対応は関係しない**)。

### 検証ゲート
- `bundle install` / `yarn install` 成功。
- `bundle exec ruby -e 'require "decidim"; puts Decidim.version'` が 0.31 系。

---

## Phase 3: 起動ブロッカー解消(本体で boot する状態に)🔴

### タスク
1. **`Rails.application.secrets` 全廃(90箇所)**: `grep -rn "Rails.application.secrets" app config lib` を列挙 → `config/secrets.yml`(0.31 廃止)の内容を `ENV`/`credentials`/`config_for` へ移設。`config/initializers/decidim.rb:5` を最優先で除去。
2. **`decidim_override.rb` HIGH 2件**: `UserAnswersSerializer`→**`UserResponsesSerializer`**(引数 `answer`→`response`、`answer_translated_attribute_name`→`response_translated_attribute_name`)/ `OrganizationAppearanceForm`・`UpdateOrganizationAppearance` の class_eval 先を新 form/command へ移設。
3. **`to_prepare` ブロック分割**(巻き込み全滅防止)。

### 検証ゲート
- `bin/rails runner 'puts Decidim.version'` 成功(boot)。
- `grep -rn "Rails.application.secrets" app config lib` = 0件。`bin/rails zeitwerk:check` パス。

---

## Phase 4: 公式アップグレード手順の実行 + 本体のみ起動確認(マイルストーン)

> **本番 RDS スナップショット復元 DB** で実施し所要時間を計測。

### タスク(RELEASE_NOTES §1.3/§3 の順序厳守)
1. `bin/rails decidim:upgrade`
2. `bin/rails db:migrate`（**Answer→Response** テーブル/カラム/質問タイプ リネーム含む)
3. `bin/rails data:migrate`
4. 一回きり rake: Valuator→Evaluator 3種 / `fix_nickname_casing` / `decidim_surveys:upgrade:fix_survey_permissions` / **`user_groups:remove`**(グループ宛 PW 再設定メール→**検証では SMTP 無効化**、本番は事前告知) / `verifications:revoke:sms`（MD5→SHA256）/ `fix_action_log`・`remove_deleted_users_left_data`・`fix_deleted_private_follows`・private_exports クリーン

### 検証ゲート(=「本体のみ起動確認」)
- 全マイグレーション成功、`decidim_forms_responses` 存在・旧 `..._answers` 無し。
- **拡張 gem 無しの状態で** app 起動・ログイン・提案/コメント/添付・survey 回答(Response)・管理画面が動作。
- マイグレーション所要時間を記録(本番切替の停止時間見積り)。

---

## Phase 5: コメントアウトした gem を1つずつ有効化&ポート(都度起動確認)

**やり方**: 1モジュール有効化 → 0.31 へポート/更新 → `bundle install` → boot & 該当機能スモーク → グリーンなら次へ。壊れたら即その1モジュールに切り分けられる。

### 順序(壊れにくい順)
1. **decidim_awesome**（最小工数=follow-upstream）: upstream `decidim-ice` の `release/0.31-stable`(COMPAT `>=0.31,<0.32`)を土台に fork の独自パッチを rebase → fork に 0.31 ブランチ。`Gemfile` の branch を差し替えて有効化。`decidim_awesome.rb`/`decidim_awesome_patches.rb` を復帰。
2. **term_customizer**（custom-port、upstream に 0.31 無し）: `030-ja` を土台に `git -C .../decidim diff v0.30.5 v0.31.1 -- <path>` を参照して自前ポート。
3. **navigation_maps**（custom-port）
4. **polis**（custom-port）
5. **broadlistening-view**（custom-port / takahashim 調整）
6. **独自 gem 修正**: `decidim-user_extension` の `trigger_omniauth_registration`→**`trigger_omniauth_event`**(新シグネチャ、`omniauth_login` 分岐・`NeedTosAcceptance`/`RecordInvalid` rescue を握り潰さない)。`CreateRegistration`/`UpdateAccount`/`DestroyAccount` prepend と Form class_eval の動作確認。OAuth scope `public`→`profile`(City OS)。

### 各モジュール有効化ごとの検証ゲート
- `bundle install` 解決 + boot 成功 + 該当機能スモーク（awesome フォーム / 用語 / 地図 / polis / broadlistening）。

### さらに Phase 5 で処理する cfj 固有修正
- **MED initializer**: `disable_messaging.rb`(`group_tabs`→UserGroup 削除で no-op→`user_tabs` 再ターゲット/撤去、`reportable_author_name` の `normalized_author`→`author`)。
- **Deface 6件**: 🔴 `officializations/index/remove_conversation_link`(操作列ドロップダウン化)筆頭にセレクタ一致を再確認・修正。
- **未マージ PR の 0.31 版化**: #852 を `PublishResponsesController` へ、#851 の MultipleAttachmentsMethods 再検証、#850 を user_extension 変更と統合。

---

## Phase 6: フロントエンド(shakapacker 8 + npm 0.31 + CSP)

### タスク
1. **shakapacker 7→8.3**: `config/shakapacker.yml` 移行・binstub 更新(`git -C .../decidim show v0.31.1:config/shakapacker.yml` を copy 元に)。
2. `@decidim/*` npm 0.31 化(esbuild `^0.19`/tailwind `^3.4`/postcss-preset-env `^9` 追随)。
3. editor 拡張: tiptap 非破壊(`@tiptap/core 2.1.13` 同一)。0.31 削除の `editor/extensions/hashtag`・`heading` を `decidim_kit/index.js`・`toolbar.js` が import してないか確認。
4. **ActiveStorage `public:true`(S3)→ アセット URL 形式変更 → `content_security_policy.rb` の `img-src`/`media-src`/`connect-src` を更新**。

### 検証ゲート
- `bin/shakapacker`(build)成功、jest グリーン、editor/地図/comments 手動 OK、CSP 違反なし。

---

## Phase 7: インフラ / CI / 新 dev 環境デプロイ

### タスク
1. CI(`_check.yaml`/`_deploy.yaml`): ruby `3.3.4→3.3.11`、node `20.18.3→22.14.0`。
2. `Dockerfile`: ベースイメージ更新(Phase 2 と一致)。
3. **新 dev スタックへデプロイ**(cdk `-c stage=dev -c tag=<0.31 image>`。先日削除した dev を 0.31 検証用に再作成)。
4. sidekiq: `metrics` キュー削除、`delete_inactive_participants` キュー追加、crontab/schedule.yml 更新。

### 検証ゲート
- CI 全ジョブ(Rubocop/RSpec/Brakeman/JS/build)グリーン。新 dev 起動・ヘルスチェック通過。

---

## Phase 8: 総合検証・スモークテスト(新 dev)

- 認証: 通常 / **LINE(PKCE)** / **City OS(scope=profile)** / facebook
- **Survey/Response**: 作成・回答・集計・公開(PublishResponses)・エクスポート
- Proposals / Comments / Attachments(#851) / 管理(Conflicts / PublishResponses / 権限)
- fork 機能: awesome / term_customizer / navigation_maps / polis / broadlistening-view
- 日本語全文検索(BigM/pg_search)・通知・メール
- **セキュリティ再確認**: Dependabot alert の **activestorage CRITICAL** ほか Rails/devise/shakapacker/puma/decidim 系が解消

### 検証ゲート
- 上記すべて OK + `bundle exec rspec` 全体グリーン + 影響インベントリ HIGH/MED 全消化。

---

## Phase 9: 本番ブルーグリーン切替(prd-v030 方式)

1. 本番 RDS スナップショット → マイグレーション時間最終確定(Phase 4 実測)。
2. 新本番スタック(0.31)構築・データ移行(メンテ枠、user_groups:remove メール/SMS revoke を事前告知)。
3. CloudFront/DNS 切替。旧 prd-v030 は一定期間保持(即時ロールバック)。
4. 監視(CloudWatch alarm/アクセスログ/Sidekiq/メール到達)。
- **ロールバック**: CloudFront/DNS を旧へ戻す + DB を移行前スナップショットから復元。

---

## Phase 依存関係(実行順)
```
1 (branch + 外部gemコメントアウト)
  → 2 (本体のみ bundle/yarn 解決)
  → 3 (boot: secrets/serializer/appearance)
  → 4 (公式手順 + 本体のみ起動確認 = マイルストーン)
  → 5 (gem を1つずつ有効化&ポート + cfj固有修正 + 未マージPR)
  → 6 (frontend/shakapacker/CSP)
  → 7 (CI/Docker/新dev)
  → 8 (総合検証)
  → 9 (本番ブルーグリーン切替)
```

## 工数の山(リスク順)
1. **Phase 5 の fork 4モジュール自前ポート**(upstream 支援なし。awesome のみ追従で楽)
2. **Phase 3 の secrets 全廃 90箇所**
3. **Phase 6 の shakapacker 8 移行**
4. **Phase 4/9 の Answer→Response + 一回きり rake の本番適用**
5. Phase 5 の user_extension omniauth イベント改修

# Decidim 0.31.7 → 0.32.1 アップグレード実行計画

調査日: 2026-08-24 / 対象: decidim-cfj + decidim-cfj-cdk
前提ブランチ: `upgrade/decidim-0.31`（decidim 0.31.7 対応済み・PR #857 は Draft）
関連: `decidim-0.31-upgrade-plan.md` / **`decidim-0.31-remaining-work.md`（0.31 やり残し監査）** / **`prd-infra-issues-2026-08.md`（本番インフラ課題）**

---

## Phase 0: 前提・正本・アンチパターン（実行前に必読）

### 0.1 ドキュメントの正本（重要な罠）

- **`RELEASE_NOTES.md` は v0.32.1 タグでは空のテンプレート（88行）**。リリースブランチで rc1 公開後にリセットされる。
  **0.32 の正式手順の正本は `git show v0.32.0.rc1:RELEASE_NOTES.md`（444行）**。
- 同様に変更履歴の正本も `git show v0.32.0.rc1:CHANGELOG.md`（601行）。v0.32.1 の `## [0.32.0]` はバックポート一覧のみ。
- **リリースノート §3.3 の rake タスク名は誤り**。`decidim:upgrade:fix_deleted_private_follows` ではなく
  **`decidim:upgrade:fix_deleted_members_follows`**（0.32 でリネーム済み）。

### 0.2 プラットフォーム要件（実測差分）

| 項目 | 0.31.7（現在） | 0.32.1 |
|---|---|---|
| Ruby | 3.3.11 | **3.4.7**（全gemspec `~> 3.4.0`） |
| Rails | 7.2.3 | **8.1**（`~> 8.1.0`） |
| rack | 2.2 | **>= 3.2.4, < 4.0** |
| shakapacker | 8.3.0 | **9.7.0** |
| paper_trail | 16 | 17 |
| pg | ~> 1.5, < 2 | >= 1.5, < 1.7 |
| redis | ~> 4.1 | >= 4.1, < 6.0 |
| 画像処理 | mini_magick | **ruby-vips（libvips 必須）** |
| tiptap | 2.1.13 | **^3.13.0** |
| React / jest | 18 / 29 | 19 / 30 |
| Node | 22.14.0 | **22.14.0（据え置き）** |
| PostgreSQL | 17.4+ | 17.4+（変更なし） |

### 0.3 差分規模（locales/spec 除外）

| 区間 | ファイル | 行数 |
|---|---|---|
| v0.30.9 → v0.31.7 | 2,825 | +61,573 / −35,202 |
| v0.31.7 → v0.32.1 | **1,571** | +39,227 / −27,290 |

規模は 0.30→0.31 の約 55%。ただし **Rails メジャー跨ぎ・OS依存追加・全URL構造変更**を含むため体感難易度は同等〜やや上。

### 0.4 0.31 と違って「今回は起きない」こと（確認済み）

- **core JS のパス移動なし**。`src/decidim/refactor/moved/` は 0.31.7 / 0.32.1 とも 9 ファイルで不変。
  各 fork モジュールが import している core 資産（`refactor/support/stimulus` / `editor/extensions/decidim_kit` /
  `admin/*.component` / `refactor/moved/autocomplete` / `a11y` / `utilities/text` / `refactor/moved/icon` /
  `legacy/_variables.scss`）は**全件 0.32.1 に存在**。
- **tailwind は v3 のまま**（^3.4.19）。v4 移行の兆候なし。
- **新規 ENV / SSM パラメータは不要**。`decidim-core/lib/decidim/env.rb` は差分ゼロ。
- **CDK の定時タスク7本は全て 0.32.1 に存在**。0.31 の `decidim:metrics:all` のような廃止はゼロ。
  crontab 推奨一覧（`docs/modules/install/pages/index.adoc`）も 0.31.7 と完全同一。
- **CSP のコア実装に差分ゼロ**。

### 0.5 アンチパターン

- ❌ リリースノート §3.6 の `SMTP_STARTTLS_AUTO` sed 置換を**適用しない**。
  `.present?` 版は文字列 `"false"` を truthy 判定するため、`config/environments/production.rb:87` の現行実装
  （`Decidim::Env.new("SMTP_STARTTLS_AUTO", "true").value != "false"`）を壊し、dev/staging の mailpit が死ぬ。
  CDK `lib/decidim-stack.ts:174` が dev/staging に `'false'` を渡している構成と現行実装は正しく噛み合っている。
- ❌ リリースノート §1.4 の S3 `public: true` を**適用しない**。cfj の S3 は `blockPublicAccess: BLOCK_ALL`
  （`decidim-cfj-cdk/lib/s3-stack.ts:19`）+ CloudFront OAC + `rails_storage_proxy` 構成。public URL は 403 になる。
- ❌ `SECRET_KEY_BASE` と `tmp/local_secret.txt` を変更しない。`decidim:upgrade:encryption` の鍵導出に影響する。
- ❌ 0.31 のとき同様、fork モジュールを先に全部ポートしてから一括で上げない。必ず「本体のみ→1つずつ復帰」。
- ❌ shadow ファイルを既存 cfj 版のまま残さない。**v0.32.1 版をベースに cfj 独自差分だけ再適用**する。

---

## Phase A: 0.31 の完了（0.32 着手の前提）

**状況更新: 2026-09-10。Phase A はほぼ完了。** 0.32 ブランチは
`upgrade/decidim-0.31` の `4e6061ce` を起点に作成済み。

### 完了済み（実機・CI で確認）

| 項目 | 状態 |
|---|---|
| A-1 main → 0.31 forward-port | **完了**。CityOS 群・アンケート並び替え・`PublishResponsesHelper` 改名すべて反映。`config/secrets.yml` は削除済み |
| A-3 `load_defaults` 6.1 → 7.2 | **完了**（`a76b4a5e`）。危険な defaults のピン留め（`key_generator_hash_digest_class = SHA1` / `yjit = false`）も実測付きで実施 |
| A-4 `destroy_all_metrics` の `NameError` | **完了**（`50570479`）。テーブルは残るため直接 SQL に置換 |
| A-4 leaflet alias | **完了**（`dfe200a2`）。実機検証の結果 alias 削除は妥当と確認し、孤児化していた `leaflet_global.js` を削除 |
| その他 | sidekiq.yml の metrics キュー削除・decidim.rb のデモ用設定4件削除・production.rb の上流追随・shakapacker `~8.3.0` |
| CDK | `upgrade/decidim-0.31`（PR #100）に main 取り込み済み。CI green |
| spec / CI | 528 examples・0 failures。CI 4本すべて pass |

### A-2. omniauth-cityos-dcp（**保留中・要注意**）

**計画書の記述は誤りだったことが実機検証で判明（2026-09-10）。**

「`Gemfile:29` のコメントアウトを解除し `tag: "v1.5.2"` へ」だけでは**動かない**。
実際に試すと `/users/sign_in` が 500 になる。

```
ActionView::Template::Error
  undefined method `user_cityos_dcp_login_omniauth_authorize_path'
```

Devise の omniauth ルートは `Decidim.config.omniauth_providers` に登録された
プロバイダにしか生成されない。0.30 では `config/secrets.yml` の
`cityos_dcp_login` ブロックから Decidim が `omniauth_providers` を組み立てて
いたため secrets に書くだけで済んでいたが、0.31 の secrets 廃止でその経路が切れた。

→ `config/initializers/decidim.rb` の `omniauth_providers` に
`line_login` と同じ形で追加する必要がある（12キー、`client_id`/`client_secret` は
`OMNIAUTH_CITYOS_DCP_*` と `OMNIAUTH_CITYOS_DCP_LOGIN_*` の2系統フォールバック）。

**方針決定: gem 側の更新を待つ。今は対応しない。** 詳細は
`decidim-0.31-remaining-work.md` の付録 C を参照。

### A-5. 残っているもの

- 一回きり rake の本番実行（切替当日）。手順書は Obsidian の
  `v0-31-0 ecs デプロイ手順.md` にチェックボックス形式で作成済み。
  **v0.31.0〜v0.31.7 の GitHub リリースノート8本すべてと突合済み**
- 本番データでの事前確認 SQL（`sms` 有効組織・CityOS 有効組織・nickname 衝突）
- 任意の掃除（`log_level` の ENV 化・`.node-version` 欠落など）

### A-6. なぜ 0.31 を飛ばさないか

（変更なし）0.30.9 → 0.32 直行は 0.31 と 0.32 の data migration を1回の切替枠で
連続適用することになり、検証もロールバックも困難。0.31 の作業は完了済みで、
破棄すると純損失。Rails 7.2 による ActiveStorage 系 CVE 対応も 0.31 で達成される。

---

## Phase 1: ブランチ準備 + 外部拡張 gem を全部コメントアウト

`upgrade/decidim-0.31`（Phase A 完了後）から `upgrade/decidim-0.32` を作成。

### タスク
1. `Gemfile` の以下をコメントアウト（**参照している initializer と配線も一緒に**）:
   `decidim-decidim_awesome` / `decidim-term_customizer` / `decidim-navigation_maps` / `decidim-polis` /
   `decidim-broadlistening-view`
   - `config/initializers/decidim_awesome.rb`, `decidim_awesome_patches.rb` も同時にコメントアウト
   - `omniauth-cityos-dcp` は decidim 非依存なので**そのまま有効で構わない**
2. `config/shakapacker.yml:17-20` の `additional_paths` から fork 由来のパスがあれば一時退避

### 検証ゲート
- `bundle install` が 0.31.7 のまま通ること（この時点ではまだ本体を上げない）

---

## Phase 2: 基盤の入れ替え（Ruby 3.4 / Rails 8.1 / sidekiq / rack）

**ここが 0.32 の真のクリティカルパス。**拡張モジュールより重い。

### 2.1 Ruby 3.4

| ファイル | 現在 | 変更後 |
|---|---|---|
| `.ruby-version` | `3.3.11` | `3.4.7` |
| `Dockerfile:3` | `FROM ruby:3.3.11-slim-bookworm` | `FROM ruby:3.4.7-slim-bookworm` |
| `Dockerfile:54` | `BUNDLER_VERSION=2.5.15` | Ruby 3.4 同梱の 2.6.x 系（要判断） |
| `.github/workflows/_check.yaml:9` | `default: 3.3.11` | `default: 3.4.7` |
| `.github/workflows/_check.yaml:77` | 表示名 `Set up Ruby 3.3.11` | `3.4.7` |
| `.github/workflows/brakeman.yaml:31` | `ruby-version: 3.3.4` | `3.4.7`（現状 `.ruby-version` とも既に不整合。inputs 化推奨） |

### 2.2 🔴 sidekiq（bundle 解決不能のブロッカー）

`Gemfile:70` の `gem "sidekiq", "6.5.12"` は `rack (~> 2.0)` / `connection_pool (>= 2.2.5, < 3)` に依存
（`Gemfile.lock:982-985`）。0.32 の `rack >= 3.2.4` / `connection_pool < 4` と衝突し**バンドルが解決しない**。

- **sidekiq 7.x へ更新**（8.x は Redis 7.0+ を要求し、CDK の ElastiCache `engineVersion: "6.x"` の変更が必要になるため避ける）
- `config/routes.rb:16` の `Sidekiq::Web` マウントを再確認
- CDK `lib/decidim-stack.ts:292` の起動コマンド `['bundle','exec','sidekiq','-C','/app/config/sidekiq.yml']` は
  sidekiq 7 でも**変更不要**

### 2.3 🟡 redis 5.x への連鎖

sidekiq 6 の `redis (>= 4.5.0, < 5)` が redis gem を 4系に抑えていた。sidekiq 7 化＋上流制約緩和（`< 6.0`）で
**redis 5.x に解決されうる** → `config/initializers/redis.rb:2` の `Redis.exists_returns_integer` は
redis 5 で削除済みのため **NoMethodError**。該当行の削除が必要。

### 2.4 🟡 mini_magick の明示ピン

`lib/decidim/map/provider/static_map/cfj_osm/map.rb` は **MiniMagick を直接呼ぶ**（`:3 require` / `:93 Image.read` /
`:98 combine_options` / `:113 composite`）。ActiveStorage 経由ではないため libvips 移行とは別問題。
4.13.2 に固定していたのは decidim-core の `mini_magick "~> 4.9"` 制約で、**0.32 でそれが消える**。
`image_processing 1.14.0` の `mini_magick (>= 4.9.5, < 6)` により 5.x に解決されうる。

→ `Gemfile` に **`gem "mini_magick", "~> 4.13"` を明示ピン**（安全策）。
　`app/previewers/heic_previewer.rb:14,24,26` の `ImageProcessing::MiniMagick` も同様に要動作確認。
　※ MiniMagick 5 での `combine_options` 可否は未検証。

### 2.5 Rails 8.1 と `load_defaults`

`config/application.rb:19` は現在 **`config.load_defaults 6.1`**。リリースノートは `7.2 → 8.1` を指示するが、
cfj は 6.1 のままなので **2世代ジャンプ**になる。

- **前提**: Phase A-3 で 6.1 → **7.2** まで上げておくこと。ここは 7.2 → 8.1 の**1世代分**にする。
- **🔴 `variant_processor` の明示ピンが 0.32 では必須になる。**
  0.31 までは `v0.31.7:decidim-core/lib/decidim/core/engine.rb:247-249` の initializer が
  `variant_processor = :mini_magick` を強制しており、ActiveStorage 側は `config.after_initialize` で読むため
  decidim が勝っていた（＝0.31 では `load_defaults` を上げても favicon は無事）。
  **0.32.1 ではこの initializer が削除され、リポジトリ全体でヒット0**（PR #15670）。
  よって Rails デフォルト（8.1 defaults なら `:vips`）が効き、
  `app/helpers/decidim/layout_helper.rb:22,42,58` の `favicon.variant(resize: "180x180!")` という
  **ImageMagick 固有のジオメトリ指定が壊れる**。
  → `config.active_storage.variant_processor = :mini_magick` を**明示**する。
  検証: `bin/rails runner 'p ActiveStorage.variant_processor'` → `:mini_magick`
- **未確認**: Rails 8.1 が `load_defaults 7.2` からの引き上げで新たに要求する項目
  （`rails app:update` が生成する `new_framework_defaults_8_1.rb` の内容）。

### 2.6 🔴 libvips（インフラ要件の追加）

0.32 は `decidim-core/lib/decidim/core/engine.rb` から
`initializer "decidim_core.active_storage_variant_processor"`（`variant_processor = :mini_magick`）を**削除**（PR #15670）。
gemspec からも `mini_magick` 依存が消え `ruby-vips ~> 2.2` が追加された。

| 対象 | 作業 |
|---|---|
| `Dockerfile` の apt ブロック（6-23行） | `libvips libvips-tools libvips-dev` を追加 |
| 同 25-38 行の imagemagick（trixie ピン） | **残す**。`heic_previewer.rb` と `cfj_osm/map.rb` が MiniMagick 直呼び |
| `.github/workflows/_check.yaml:66-69` | `libvips libvips-tools` を追加。未対応だと画像系 spec が全落ち |

- **`.ico` favicon サポートが 0.32 で削除**（libvips 非対応）。`app/helpers/decidim/layout_helper.rb:21,55` に
  `image/vnd.microsoft.icon` の分岐があるため、**本番組織が .ico を使っていないか DB で要確認**。

### 2.7 shakapacker 9.7（三点セット）

| 対象 | 作業 |
|---|---|
| `package.json:67` | `"shakapacker": "^8.3.0"` → `"^9.7.0"`（gem 側 `~> 9.7.0` と `ensure_consistent_versioning: true` により**不一致は起動時 raise**） |
| `config/shakapacker.yml:26` | `webpack_loader: 'esbuild'` → **`javascript_transpiler: 'esbuild'`**、`assets_bundler: "webpack"` 新設、`integrity:` / `early_hints:` 追加 |
| `config/shakapacker.yml:47` | `dev_server.https: false` を**削除**（webpack-dev-server 5 で廃止） |
| `package.json:10-12, 52-55` | `@decidim/*` 7パッケージを `^0.31.7` → `^0.32.1` |
| `package.json:4` | `"node": ">=18.17.1"` → `">=22.14.0"`（0.31 時点で既に乖離） |

上流ファイルで丸ごと差し替えるのがリリースノートの指示:
`decidim-core/lib/decidim/shakapacker/shakapacker.yml`（`release/0.32-stable`）

### 検証ゲート
- `bundle install` / `yarn install` が 0.32.1 で解決する
- `bin/rails runner 'puts Decidim.version'` が `0.32.1` を返す

---

## Phase 3: 起動ブロッカー解消（本体で boot する状態に）🔴

### 3.1 sortitions gem の完全削除に伴う NoMethodError

- cfj: `config/initializers/comments_count.rb:29-33`
- 上流: **`decidim-sortitions/` ディレクトリが v0.32.1 で完全消滅**。`decidim.gemspec` の依存からも削除。
- `Decidim.find_component_manifest(:sortitions)` は registry の戻りをそのまま返す
  （`decidim-core/lib/decidim/core.rb:801-803`）ため **nil → `nil.stats` で NoMethodError**。
- **危険度**: 同じ `to_prepare` ブロックに accountability / blogs / debates の3パッチが同居しており、
  **この1件で4件すべてが道連れ**になる。0.31 の `decidim_override.rb` と同じ構造の地雷。

→ sortitions ブロックを削除。ついでに initializer を機能別に分割し、道連れ構造を解消する。

### 3.2 decidim_ai の削除済みクラス参照

- cfj: `config/initializers/decidim_ai.rb:63`
  `"Decidim::Proposals::CollaborativeDraft" => "Decidim::Ai::SpamDetection::Resource::CollaborativeDraft"`
- 上流: `decidim-ai/lib/decidim/ai/spam_detection/resource/collaborative_draft.rb` を**削除**、
  `spam_detection.rb` の autoload 宣言と engine.rb のサブスクライバも除去。
- `Importer::Database` が `resource_models.values` を constantize するため、spam 学習タスクで NameError。

→ 該当行を削除。
※ `config/initializers/decidim_ai.rb:101` の `Decidim::Ai::Language.formatter = "..."` は、0.32 で
`config_accessor` → `mattr_accessor` に変わったが **writer は存続**するため互換。cfj の直接代入スタイルは安全。

### 検証ゲート
- 拡張 gem を全部コメントアウトした状態で `bin/rails s` が起動する
- トップ / `/processes` / `/assemblies` / `/users/sign_in` が 200

---

## Phase 4: 公式アップグレード手順の実行（本体のみ）

正本 = `git show v0.32.0.rc1:RELEASE_NOTES.md` §1.3。**rake 名は実態に合わせて修正済み**。

```bash
# 0. libvips（Phase 2.6 で Docker に入れておく）

# 1. Rails 8.1 defaults（Phase 2.5 の判断に従う）
#    config/application.rb: load_defaults 6.1 → 8.1
#    併せて config.active_storage.variant_processor = :mini_magick を明示

# 2. shakapacker.yml 差し替え（Phase 2.7）

# 3. Decidim のアップグレードタスク
#    中身: choose_target_plugins → upgrade_app → upgrade:shakapacker_npm
#          → railties:install:migrations → upgrade:migrations
#          → upgrade:shakapacker → decidim_api:generate_docs
#    ※ db:migrate は含まれないので別途必須
bin/rails decidim:upgrade

# 4. スキーマ移行
bin/rails db:migrate

# 5. 【0.32 新規】SHA1 → SHA256 暗号鍵ローテーション
#    SECRET_KEY_BASE を絶対に変えないこと
bin/rails decidim:upgrade:encryption

# 6. 【リネーム】リリースノートの fix_deleted_private_follows は誤り
bin/rails decidim:upgrade:fix_deleted_members_follows

# 7. gitignore
echo "/public/sw.js*" >> .gitignore

# 8. データ移行（0.32 で 12 本追加）
bin/rails data:migrate
```

### 0.32 で追加されるデータマイグレーション（12本）

```
decidim-accountability/db/data/20260113140600_reindex_results.rb
decidim-assemblies/db/data/20260104094930_remove_assemblies_types_references.rb
decidim-assemblies/db/data/20260111185230_replace_legacy_fields_to_access_mode_for_assemblies.rb
decidim-assemblies/db/data/20260210195653_move_announcement_to_content_block_on_assemblies.rb
decidim-core/db/data/20251213075429_rename_members_in_action_log.rb
decidim-core/db/data/20260319145808_rename_send_to_members_in_newsletter.rb
decidim-participatory_processes/db/data/20260104094929_remove_process_types_references.rb
decidim-participatory_processes/db/data/20260111190000_replace_legacy_fields_to_access_mode_for_participatory_processes.rb
decidim-participatory_processes/db/data/20260210195709_move_announcement_to_content_block_on_participatory_processes.rb
decidim-proposals/db/data/20260224210316_remove_collaborative_drafts_references.rb
decidim-surveys/db/data/20260314063300_reindex_surveys.rb
```
`replace_legacy_fields_to_access_mode_*` は `down` が `IrreversibleMigration`。

### 🟡 非可逆なスキーマ変更（本番前にスナップショット必須）

| migration | 内容 |
|---|---|
| `decidim-proposals/db/migrate/20250515132352_drop_collaborative_drafts_tables.rb` | 協働草案テーブル DROP |
| `decidim-assemblies/db/migrate/20260104093601_remove_assemblies_types.rb` | assemblies types 削除 |
| `decidim-participatory_processes/db/migrate/20260104093600_remove_participatory_process_types.rb` | process types 削除 |
| `decidim-core/db/migrate/2026020820140{5,6,7}_remove_user_group_*.rb` | user group カラム・テーブル削除 |
| `.../20260208201400_remove_user_group_blogs.rb` ほか5本 | blogs/comments/debates/initiatives/meetings の `decidim_user_group_id` 削除 |
| `decidim-core/db/migrate/20251205122428_rename_..._to_members.rb` / `20251216185133_rename_privatable_to_...` | **members リネーム** |
| `20251203071213_remove_legacy_file_column_from_attachments_table.rb` | attachments 旧 file カラム削除 |
| `2025111*_remove_legacy_images_from_*_module.rb`（6本） | ActiveStorage 移行前の旧画像カラム削除 |

### 事前に本番 DB で確認すべきこと（機能削除の影響）

- [ ] **`decidim-sortitions`** — 抽選コンポーネントを使っている組織があるか
- [ ] **Collaborative Drafts** — 協働草案データがあるか（DROP されるため事前エクスポート要否）
- [ ] **AssembliesType / ParticipatoryProcessType** — 使用中か
- [ ] **`.ico` favicon** — 使用組織があるか（0.32 で非対応）

### 検証ゲート
- 拡張 gem 無しで起動・主要ページ 200・`data:migrate` 完走
- `db/schema.rb` 再生成時に `pg_bigm` 拡張（`20240713180919_enable_pg_bigm_extension.rb`）が落ちないこと

---

## Phase 5: cfj 固有コードの 0.32 対応 🟠

### 5.1 参加型プロセス詳細ページの shadow（**500 になる**）

- cfj: `app/views/decidim/participatory_processes/participatory_processes/show.html.erb:23-27`
- **`private_space?` は v0.32.1 のモデル層から完全消滅**（grep のヒットは data migration と importer のみ）。
  0.32 は `access_mode` enum に統合され、`restricted?` / `transparent?` / `open?` / `can_participate?(user)` が新 API。
- i18n キー `decidim.participatory_processes.show.private_space` も削除 →
  `decidim.participatory_spaces.show.restricted_space` / `transparent_space`（`decidim-core/config/locales/en.yml:1571-1572`、ja 訳あり）
- 同ファイルの `edit_link` 第1引数も `resource_locator(...).edit` →
  `decidim_admin_participatory_processes.edit_participatory_process_landing_page_path(...)` に変更。

→ **v0.32.1 版をベースに cfj 独自差分だけ再適用**。

### 5.2 deface セレクタの消滅（**サイレント故障**）

- cfj: `decidim-user_extension/app/overrides/decidim/admin/officializations/index/user_extension_modal_override.html.erb.deface:1`
  = `insert_after "div#user-groups"`
- 上流 `decidim-admin/app/views/decidim/admin/officializations/index.html.erb`:
  v0.31.7 の `<div class="card" id="user-groups">` → **v0.32.1 で `id="user-groups"` が削除**。
  v0.32.1 全文（133行）に `user-groups` は存在しない。
- Deface は**不一致時に警告ログを出すだけで override をスキップ**するため、`_show_user_extension_modal` が
  描画されなくなる。例外は出ない。

→ `insert_bottom "div.card"` か `insert_after "table.table-list"` 等へ変更。
　同時に `_show_user_extension_modal.html.erb:31-69` と `user_extensions/show.html.erb:6` の
　jQuery（`$()`）依存も確認する。

**cfj 側 `app/overrides/` の他6件は全て安全**（override 先5本が v0.32.1 に存在、うち4本は差分ゼロ。
officializations/index も `<% unless current_user == user %>` ブロック構造は無変更でセレクタ一致）。
`user_extension_override.html.erb.deface` の `insert_bottom "td.table-list__actions"` も v0.32.1:53 に残存。

### 5.3 🔴 GraphQL `UserModerationType` の nil ガード漏れ（0.32 で新規に必要）

**0.32 で新規追加された型に、既知のバグと同じ nil ガード漏れがある。**

```ruby
# decidim-core/lib/decidim/api/types/user_moderation_type.rb（v0.32.1、0.30/0.31 には存在しない）
field :block_reasons, GraphQL::Types::String, "...", null: true
field :blocking_user, UserType, "...", null: true

def block_reasons
  object.blocking.justification        # ← nil ガードなし
end

def blocking_user
  object.blocking.blocking_user        # ← nil ガードなし
end
```

collection の絞り込みもオープンデータと**完全に同一**:

```ruby
# decidim-api/lib/decidim/api/query_type.rb:92-94（v0.32.1）
def moderated_users
  Decidim::UserModeration.joins(:user)
    .where(decidim_users: { decidim_organization_id: organization&.id })
    .where.not(decidim_users: { blocked_at: nil })    # ← blocked_at で絞る
end
```

`object` は `Decidim::UserModeration` で、`has_one :blocking` は `decidim_users.block_id` 経由
（`decidim-core/app/models/decidim/user.rb:20`）。**`blocked_at` は入っているが `block_id` が NULL の
ユーザーが1件でもあると `NoMethodError`** になる。フィールドが `null: true` なのにガードが無い矛盾。

→ **0.32 では `{ moderatedUsers { blockReasons } }` が公開 GraphQL エンドポイントで例外になる。**

| 経路 | 0.30.9 | 0.31.7 | 0.32.1 |
|---|---|---|---|
| オープンデータ（`OpenDataBlockedUserSerializer`） | 🔴 バグあり | 🔴 バグあり | 🔴 バグあり |
| **GraphQL（`UserModerationType`）** | ➖ 型が存在しない | ➖ 型が存在しない | 🔴 **バグあり** |

**対応**: `config/initializers/open_data_blocked_user_serializer_override.rb`（PR #869、0.30/0.31 向け）と
**同じ形の override を `UserModerationType` にも追加する**。

```ruby
def block_reasons
  object.blocking&.justification
end

def blocking_user
  object.blocking&.blocking_user
end
```

同じ根本原因（collection は `blocked_at`、consumer は `block_id` を前提）なので、
**上流へは2箇所まとめて報告する**のが妥当。本質的には `Decidim::UserModeration#blocking` の扱いを
上流が整理すべき。

※ 発見の経緯: PR #869 のレビューで takahashim さんから指摘。

### 5.4 削除済みモデルを参照する DestroyAll 系コマンド（NameError）

| cfj | 参照 | 呼び出し元 |
|---|---|---|
| `app/commands/decidim/assemblies/destroy_all_assemblies.rb:24` | `Decidim::AssembliesType` | `lib/tasks/delete.rake:175` |
| `app/commands/decidim/participatory_processes/destroy_all_participatory_processes.rb:28` | `Decidim::ParticipatoryProcessType` | `lib/tasks/delete.rake:189` |
| `app/commands/decidim/proposals/destroy_all_proposals.rb:31` | `Decidim::Proposals::CollaborativeDraft` | `lib/tasks/delete.rake:91` |

→ 該当参照を除去。テナント削除タスクが落ちる。
※ `lib/tasks/delete.rake:281` の `Decidim::Metric` は **0.31.7 にも 0.32.1 にも存在しない既存の壊れ**。ついでに修正。

### 5.5 コメントの15秒ポーリングが破綻（shadow）

- cfj: `app/packs/src/decidim/comments/comments.component.js:25, 234, 242-248, 273, 289-293`
- 上流は同ファイルから**ポーリング機構を全削除**（`pollingInterval` / `_pollComments` / `after` パラメータが全消滅、
  v0.32.1 で `pollingInterval` の grep は0件）。Stimulus の `load_more_comments` / `show_replies` による
  ページネーションに置換され、`comments_controller.rb` の params も `offset` / `load_more` / `alignment` に変更。
- cfj 版は `after=` 付きで叩き続けるが 0.32 の index は無視して1ページ目を返し、`index.js.erb` が
  `.comment-thread` を全削除して差し直す → **「もっと見る」で読み込んだコメントが15秒ごとに消えて巻き戻る**。

→ **cfj の shadow を捨てて上流版を採用するのが正解**。本番負荷の原因だった15秒ポーリングは上流で解消済み。
　（`project_access_log_analysis` の「Decidim 15秒ポーリング」問題がここで解決する）

- 併せて同ファイル `:174` の `changeReportFormBehavior` は **import もローカル定義もない未定義関数**
  （0.31 時点で既に ReferenceError。上流は Stimulus `report-form` に移行済み）。shadow 廃止で同時に解消。

### 5.6 エディタ拡張の Tiptap 3 対応

- cfj: `app/packs/src/decidim/editor/extensions/decidim_kit/index.js:45-50`（shadow）
- 上流は同位置に **`link: false, underline: false, trailingNode: false`** の3行を追加（commit `521c686743`）。
  v0.32.1 の `package-lock.json` で `@tiptap/starter-kit@3.13.0` が extension-link / extension-underline /
  extensions を依存に持つことを確認済み。
- cfj 版は link/underline を**二重登録**し、decidim 独自 Link（リンクダイアログ等）が効かなくなる恐れ。

→ 上流の3行を取り込む。
- `app/packs/src/decidim/cfj/editor/extensions/tag_edit/index.js:30` の `setContent(x, true)` は Tiptap 2 のシグネチャ。
  v3 では `{ emitUpdate: true }` へ。
- `simple_image` の parseHTML 競合は要実挙動確認。

### 5.7 モバイルアカウントメニューの閉じるボタン

- cfj: `app/views/layouts/decidim/header/_main_links_mobile_account.html.erb`（shadow）
- 上流は `data-controller="assign-role"` と `id="dropdown-trigger-links-mobile-close"` を追加。
  cfj が shadow していない `_main_links_mobile_item_account.html.erb:4` が
  `data-close-button="dropdown-trigger-links-mobile-close"` でその id を参照。
- → cfj の shadow に id が無いため閉じるボタンが機能しない。上流版ベースで作り直す。

### 5.8 掃除・軽微

- `app/views/decidim/proposals/collaborative_drafts/show.html.erb` — 上流でビュー群13ファイルが削除済み。**孤児なので削除**
- `config/initializers/disable_messaging.rb:48-55` `HideGroupConversationsTab` — `group_tabs` は 0.31.7 / 0.32.1 とも
  存在せず既に死にコード（`super` を呼ばないので無害）。削除
- `config/locales/taxonomy_ja.yml:93-95, 194-197, 284-297` の sortitions / `decidim.admin.titles.*` 系**8キー**が
  上流から消滅（訳が死ぬだけ）
- `config/locales/en.yml:28-31` と `:32-44` の `decidim.devise` 重複キー（0.31 からの既存問題）
- `lib/tasks/replace_to_null.rake:6, 24` の announcement クリア — 0.32 で announcement が content block へ移設
  （`move_announcement_to_content_block_on_*`）。**カラムは削除されないので落ちないが無効化**する
- `app/controllers/decidim/editor_images_controller.rb:28` / `decidim-user_extension/.../postages_controller.rb:27` の
  `:unprocessable_entity` → `:unprocessable_content` へ置換推奨。
  **rack 3.1.18 では `OBSOLETE_SYMBOLS_TO_STATUS_CODES` に残り警告なしで 422 を返す**ため必須ではない。
  ただし **rack 3.2.4 での挙動は未検証**
- `app/controllers/decidim/debates/versions_controller.rb:14` — 上流が `versioned_resource` から `present()` を除去し
  `add_breadcrumb_item` を新設。即エラーにはならないがパンくずにディベート名が出なくなる
- `app/packs/entrypoints/application.js` — どのレイアウトからも参照されておらず、`leaflet_global.js` の
  `window.L` 統一処理は本番未実行の可能性。要否判断

### 🟢 安全と確認済み（作業不要）

- **`config/initializers/decidim_override.rb` の全パッチ（239行）が健在**。`CommentsController#order` /
  `CommentsHelper#inline_comments_for`（差分ゼロ）/ `UserResponsesSerializer#hash_for` / `LinksController#escape_url` /
  `CloseMeetingReminderGenerator#space_admins` / `RegistrationForm` / `OmniauthRegistrationForm` /
  `RegistrationsController#configure_permitted_parameters` / `UpdateOrganization.fetch_file_attributes` /
  `OrganizationForm` / `Decidim::Organization#validates_upload` / コンポーネント manifest の `settings(:global)` / `on(:update)`
- **prepend 対象メソッドの `super` 先 13個を全件確認**。`recipients_count` / `bulk_create` / `bulk_destroy` /
  `bulk_unreport` / `present_user_name` / `update_attachment_title_for` / `keep_ids` / `attachments_attached_to` /
  `blob_url` / `local_blob_url` / `remote_url=` / `create_verification_conflict` / `escape_url` —
  差分は `:unprocessable_entity` → `:unprocessable_content` と空行のみでシグネチャ不変
- **shadow 21件のうち18件が上流で差分ゼロ**。`search.rb` は `order("datetime DESC")` → `order(datetime: :desc)` のみ、
  `blogs/posts/show` は `post: post` → `post:` のみで機能同等
- **`decidim-user_extension` の prepend フック先4つが全て差分ゼロ**（`create_user` / `update_personal_data` /
  `create_or_find_user` / `attach_avatar`）。`destroy_user_account!` も差分は内部 private メソッド名
  （`destroy_participatory_space_private_user` → `destroy_member`）のみで cfj が触る箇所は無変更。
  **0.31 のような作り直しは不要**
- `RegistrationForm` / `OmniauthRegistrationForm` / `AccountForm` / `Admin::Permissions` / `AuthorizationHandler` /
  `Renewable` / `Officializations::Filterable` / `OrganizationDashboardConstraint` / `register_workflow` — 全て差分ゼロ
- **`omniauth-line_login` は Decidim 参照ゼロ**（gemspec の homepage 文字列のみ）。omniauth 2.1.4 は rack 上限なしで
  rack 3.2 と互換
- **cfj 独自 db/migrate は4件のみで衝突ゼロ**（`direct_message_types` / `available_authorizations` / `pg_bigm` /
  `active_hashcash`）。タイムスタンプ順序も問題なし
- **Decidim 設定 API**: cfj が使う24個の設定アクセサ（`available_locales` / `maps` /
  `content_security_policies_extra` / `omniauth_providers` / `consent_cookie_name` / `expire_session_after` 他）は
  全て存続。`Decidim::Env` / `icon_registry` / `content_block_registry` / `component_manifest` / `stats_registry` /
  `settings_manifest` は全ファイル差分ゼロ。`config_accessor` の使用は cfj 本体に**0件**
- **i18n**: cfj が上書きする decidim キー（ja 252 / en 34）を全件突合し、削除・移動は上記8件のみ。
  **leaf → 親ノード化による deep merge 破綻は0件**。0.32 新規 en キー253件のうち ja 欠落は複数形 `.one` の1件だけ
- **spec**: 使用中の factory 38種・trait 全件が v0.32.1 に存在。0.32 で消えた factory
  （`assemblies_type` / `collaborative_draft` / `sortition` / `participatory_space_private_user`）は cfj 未使用
- **フロント**: import 先パス16件すべて v0.32.1 に実在。shadow 7件のうち5件は上流で無変更。leaflet 1.9.4 据え置き

---

## Phase 6: 拡張モジュールを1つずつ有効化・ポート（壊れにくい順）

### 順序と方針

| # | モジュール | 方針 | 難易度 |
|---|---|---|---|
| 1 | **term_customizer** | mainio `main` が既に **VERSION 0.32.0 / `~> 0.32.0` / ruby >=3.4 / rails ~>8.1**（2026-08-19）。`main` から `032-ja` を切り、cfj の1行パッチ（`i18n_backend.rb` の `rescue ::ActiveRecord::StatementInvalid` → `StandardError`）を再適用 | **最小** |
| 2 | **broadlistening-view** | `DECIDIM_VERSION = ">= 0.29.0"`（上限なし）＝ **gemspec 変更不要**。`decidim_core_shim.js` の3パス（`utilities/text` / `refactor/moved/icon` / `a11y`）は全て 0.32.1 に存在。スモークテストのみ | **最小** |
| 3 | **polis** | 上流2つとも死亡（OSP 2022-10 / takahashim 2024-11）＝ cfj 単独保守。gemspec が `decidim-core` を**バージョン文字列完全一致で pin** しているため `version.rb` を `"0.32.1"` に。`.ruby-version` も 3.3.4 → 3.4.7。**0.30→0.31 は2ファイル / ±5行だった**実績 | 低 |
| 4 | **navigation_maps** | ❌ **上流にもコミュニティ fork 12件にも 0.32 対応が皆無**。Platoniq main は `[">= 0.31", "< 0.32"]`。**cfj が自前ポート**（VERSION 1.9.0 想定）→ Platoniq に PR。core import は `a11y` と `legacy/_variables.scss` のみで両方 0.32 に健在、`leaflet-geoman` は自前同梱 → **フロント破壊は想定されない**。破壊があるとすればロケール URL（管理画面のマップ編集リンク）と Rails 8.1 周り | 中（**最大の外部ブロッカー**） |
| 5 | **decidim_awesome** | ⏳ 上流 `decidim-ice` に `upgrade-32` ブランチ実在（VERSION 0.15.0 / `[">= 0.32", "< 0.33"]` / ruby >=3.4 / Gemfile.lock は decidim 0.32.0・rails 8.1.3）。**PR #623 は draft・未マージ**（32 commits / 170 files / +12,443 −5,744、最終更新 2026-07-22、`mergeable: false`）。CI は **18/18 success**、サブ PR #624〜632 は全マージ済み。残りは **issue #628 の手動 QA 約30項目（2026-08-07 時点で全未チェック）**。`ActiveSupport::Configurable` 脱却は完了済み（独自 `self.config_accessor` を定義） | 低〜中（**待ち**） |

### 上流状況の再確認（2026-09-10）

計画書作成時（2026-08-24）から動いている。着手時は必ず再確認すること。

| モジュール | 2026-09-10 時点 | 計画書からの変化 |
|---|---|---|
| term_customizer | mainio `main` / `develop` とも VERSION 0.32.0・`~> 0.32.0`（push 2026-08-19） | 変化なし |
| decidim_awesome | PR #623 `upgrade-32` は **draft のまま**だが **`mergeable: MERGEABLE` に改善**。37 commits / 178 files / +12,613 −5,755、最終更新 **2026-09-03** | 計画書時点は 32 commits / 170 files / `mergeable: false`。**コンフリクトが解消され前進している** |
| navigation_maps | Platoniq に 0.32 系ブランチ依然なし（`release/0.31-stable` が最新、push 2026-09-03） | 変化なし。**自前ポート確定** |
| polis | takahashim 上流は 0.24.3 のまま、最終 push 2024-11-18 | 変化なし。cfj 単独保守 |
| broadlistening-view | takahashim `main` が `>= 0.29.0`（上限なし、push 2026-06-15） | 変化なし |

**注意**: 上流の 0.32 対応は `main` ではなく別ブランチにあることがある
（awesome は `upgrade-32`、term_customizer は `main` と `develop` 両方）。
**デフォルトブランチだけ見て「未対応」と判断しないこと**（2026-09-10 に一度誤判断した）。

### awesome の扱い（判断が要る）

cfj fork `release/0.31-stable` は upstream + **1コミットのみ**（`api_fetcher.js` に `.fail(function() { callback(null); })` を
足す1行 = awesome map のスピナーが消えない件の修正）。**`upgrade-32` にはこの修正が入っていない**。

- **待つ場合**: 上流が `main` マージ → `release/0.32-stable` を切るのを待つ。cfj の作業は「追従＋1行」で済む。
  上流は極めて活発（2026-08-24 も push あり）。
- **急ぐ場合**: cfj fork に `upgrade-32` を**固定 SHA で**取り込み（draft ブランチは force-push されうるため）、
  1行修正を再適用。同時に upstream `upgrade-32` へその1行を PR。

### 各モジュール有効化ごとの検証ゲート
- `bundle install` 解決 → `bin/rails shakapacker:compile` → 起動 → component/content_block 登録確認 →
  公開ページ・管理ページ 200 → Translation missing なし

**⚠ dev 環境のハマり（0.31 で踏んだもの・再発する）**: compose が `.:/app` でホストをマウントするため、
Docker build 時にイメージへ精コンパイルした `public/decidim-packs` をホスト側の古い manifest が覆い隠す。
→ **再ビルド後にコンテナ内で `bin/rails shakapacker:compile` を実行**しホスト public に書き出す。本番は bind mount 無しなので発生しない。

---

## Phase 7: ロケールプレフィックス URL 対応 🟠（インフラ横断）

0.32 の PR #14432 で **全 URL に `/:locale` が付く**。

- `decidim-core/config/routes.rb` が `scope "/:locale"` で全体を包む
- 新規: `decidim-core/lib/decidim/routes.rb` / `routes/locale_redirects.rb` / `lib/decidim/locale_router_detector.rb`
- `get "/", to: redirect(&locale_redirector("/"))` / `get "/admin/*rest", to: redirect { ... }` で旧 URL は 301
- 削除: `layouts/decidim/footer/_main_language_chooser.html.erb`, `.../header/_mobile_language_choose.html.erb`
- CHANGELOG #16635: 「Remove unnecessary locale argument in URL helpers」→ `xxx_path(locale: I18n.locale)` は
  **渡すと二重になる**

### 確認・変更が要る箇所

- [ ] **CloudFront ビヘイビア**（`decidim-cfj-cdk/lib/cloudfront.ts`）— パスパターンの前提が崩れないか。
      特に `cloudfront.ts:430` の `/s3/*` ビヘイビアと `:372` の CF Function（`/s3/` プレフィックス剥がし）
- [ ] **WAF ルール** — パスベースの条件があれば全部
- [ ] **OAuth callback URL** — LINE ログイン / CityOS DCP の登録済み callback
- [ ] **robots.txt / sitemap**
- [ ] **`Decidim::CloudfrontLogoHelper`**（`https://<org.host>/s3/<blob.key>`）— ロケール付与の影響
- [ ] 既存 SEO 被リンク・外部連携の固定 URL — 301 で救済されるかを実機確認
- [ ] cfj の view / helper 内の `_path(locale:)` 呼び出し

### 併せて対応

- **フィルタパラメータ構造の変更（rack 3 起因、PR #16103）**
  旧 `"filter" => { "with_any_taxonomies[4]" => [""] }` → 新 `"filter" => { "with_any_taxonomies" => { "4" => [""] } }`
  カスタムフィルタ・system spec・保存済み検索 URL に影響
- **ヘッダ/メニュー UI 刷新（PR #15134）** — `GlobalMenuCell` / `MenuBreadcrumbLastActivityCell` /
  `ParticipatorySpaceDropdownMetadataCell` と各空間版、`layouts/decidim/header/_menu_breadcrumb_*`（5ファイル）、
  JS の `sticky_header/controller.js` / `dropdown_menu.js` / `identity_selector_dialog.js` が削除。
  `decidim-core/lib/decidim/core/menu.rb` から `register_menu!` / `register_mobile_menu!` が削除
  （core が `:menu` / `:mobile_menu` に "Home"/"Help" を登録しなくなった）。**registry 自体は健在**。
  cfj にメニュー改変があれば要再実装

---

## Phase 8: GraphQL API の破壊的変更

| # | 変更 | 対応 |
|---|---|---|
| 1 | `QueryType.user` / `users` の型が `Core::AuthorInterface` → **`Core::UserType`** | `... on User { }` インラインフラグメントを使うクライアントは書き換え |
| 2 | `ParticipatoryProcessTypeType` 削除 | — |
| 3 | `SortitionType` / `SortitionsType` 削除 | — |
| 4 | `createMeetings` → **`createMeeting`** | ミューテーション名変更 |
| 5 | `Decidim::QueryExtensions`（core）削除 → `decidim-api/lib/decidim/api/query_type.rb` にインライン化 | **`Decidim::Api::QueryType.include MyExtensions` パターンは 0.32 でも有効**。`Decidim::QueryExtensions` を直接参照/prepend していたら壊れる |
| 6 | `AuthorInterface.resolve_type` が `Decidim::User` → `Decidim::UserBaseEntity` 判定に | — |

追加（非破壊）: proposals / meetings / debates の書き込みミューテーション大量追加、`ParticipantDetailsType` /
`StaticPageType` / `ModerationType` / `AccessModeEnum` 等の新型、`AttachmentType` にフィールド追加、
`UserType` に `about` / `badges` / `followers_count` 等追加。

→ **cfj の外部 API 利用者（City OS 連携等）への影響を要確認**。

---

## Phase 9: インフラ / CI / 新 dev デプロイ

### CDK（`decidim-cfj-cdk`）

- [ ] **定時タスク7本は変更不要**（全て 0.32.1 に存在）。ただし `lib/decidim-stack.js:416` に
      `decidim:metrics:all` が残存 — `.gitignore` された古いビルド生成物なので `npm run build` で再生成
- [ ] **新規 ENV / SSM は不要**
- [ ] **libvips** を Docker イメージに含めたことの確認（ECS タスクは同イメージを使う）
- [ ] `decidim:upgrade:encryption` を**デプロイ後に ECS 一時タスクとして手動実行**する手順を用意（cron 化は不要）
- [ ] ロケール URL 対応（Phase 7）に伴う CloudFront / WAF 変更
- [ ] sidekiq 8 を選ぶ場合のみ ElastiCache `engineVersion` 変更（**sidekiq 7 なら不要**）

### CI

- [ ] `_check.yaml:9,77` の Ruby、`:66-69` の apt に libvips、`brakeman.yaml:31` の Ruby
- [ ] `decidim-dev` の `TargetRubyVersion: 3.3 → 3.4`、新カスタム Cop **`Decidim/MessageAntipattern`**
      （spec/test 配下対象）、`rubocop` 制約緩和（`~> 1.78.0` → `>= 1.78, < 1.87`）による新規オフェンス
- [ ] `rubocop-yard` が decidim-dev の新規依存として自動追加
- [ ] `parallel_tests` が `>= 4.2, < 6.0` に緩和（cfj lock は 4.10.1）。`_check.yaml:114-125` の
      `parallel:create` / `parallel:migrate` / `parallel_test` が 5.x で動くか**未検証**
- [ ] brakeman が 8.x に上がる可能性（`brakeman.yaml:36,47` の警告数）

### 変更不要（確認済み）

- Node 22.14.0（Dockerfile / `_check.yaml:87,146` / CDK）
- `_deploy.yaml:65` の `node-version: '24'`（CDK 実行用、decidim と無関係）
- `entrypoint` / `compose.override.yml`
- `config/storage.yml`（Azure は既にコメントアウト済み、S3 は `public:` 指定なし＝private で正しい）
- `config/initializers/content_security_policy.rb`（全行コメントアウトのままで可）

---

## Phase 10: 総合検証・本番ブルーグリーン切替

`decidim-0.31-upgrade-plan.md` Phase 8/9 と同方式。`prd-v030` → `prd-v032` スタック。

### 本番切替前の必須確認
- [ ] スナップショット取得（非可逆 migration が多数）
- [ ] `SECRET_KEY_BASE` が変わっていないこと
- [ ] sortitions / collaborative drafts / space types / `.ico` favicon の利用実態（Phase 4 のチェックリスト）
- [ ] ステージングで添付・アバター・favicon・静的地図の表示確認（libvips / mini_magick 混在構成のため）
- [ ] ロケール URL 化後の外部連携・OAuth callback の疎通

---

## Phase 依存関係

```
A (0.31 完了: forward-port + cityos v1.5.2 + 本番切替)
  → 1 (branch + 外部gemコメントアウト)
  → 2 (基盤: Ruby3.4 / Rails8.1 / sidekiq7 / redis / mini_magick / libvips / shakapacker9)
  → 3 (boot: sortitions / decidim_ai)
  → 4 (公式手順 + data:migrate + 本体のみ起動確認 = マイルストーン)
  → 5 (cfj固有: shadow作り直し / deface / DestroyAll / 掃除)
  → 6 (拡張モジュール 1つずつ)  ← 4 と並行で navigation_maps ポート可
  → 7 (ロケールURL: アプリ + CDK)
  → 8 (GraphQL)
  → 9 (CI / Docker / 新dev)
  → 10 (総合検証 → 本番切替)
```

---

## 工数の山（リスク順）

1. **Phase 2 の基盤入れ替え** — Rails 7.2→8.1 メジャー跨ぎ + rack 3 + sidekiq/redis の連鎖。
   **モジュールより重い、真のクリティカルパス**（`load_defaults` は Phase A-3 で 7.2 まで上げておく前提）
2. **Phase 7 のロケールプレフィックス URL** — アプリだけでなく CloudFront / WAF / OAuth callback / SEO に波及
3. **Phase 6-4 の navigation_maps 自前ポート** — 上流にもコミュニティにも 0.32 が存在しない
4. **Phase 6-5 の awesome 待ち** — 上流 PR #623 のマージ次第。cfj の依存度が高く迂回不能
5. **Phase 5 の shadow 作り直し4件** — process show / comments.component.js / decidim_kit / mobile_account
6. **GraphQL `UserModerationType` の nil ガード**（5.3、0.32 で新規に必要）
6. **Phase 4 の非可逆 migration の本番適用**

---

## 未確認事項（着手時に潰す）

1. Rails 8.1 の ActiveStorage 既定 `variant_processor` と、`load_defaults 6.1` の受理可否
2. MiniMagick 5.x での `combine_options` / `composite` の可否
3. **rack 3.2.4** での `:unprocessable_entity` の扱い（3.1.18 までは警告なしで 422 と実証済み）
4. deface 1.9.0 の Rails 8.1 実動作（decidim の依存ではなく cfj 独自導入）
5. Rails 7.2→8.1 / rack 2.2→3.2 に伴う周辺 gem の互換性
   （rspec-rails / Capybara / Devise / wicked_pdf / puma_worker_killer / newrelic_rpm / aws-xray）
6. Tiptap 3 での `tagEdit`（スキーマ仕様なしの `Node.create`）と `SimpleImage` の parseHTML 競合
7. shakapacker.yml に `webpack_loader` キーが残った場合の実エラー挙動
8. cfj の spec / jest が実際に green か（本調査は静的突合のみ）

---

## 既存の壊れ（0.32 起因ではないが同時に直す価値あり）

- `decidim-user_extension/app/commands/concerns/decidim/user_extension/create_omniauth_commands_overrides.rb:21`
  の `@user.update!(user_extension: ...)` — `Decidim::User` に `user_extension` 属性/関連は 0.31.7・0.32.1 とも存在せず、
  engine 側にも追加箇所なし。omniauth 登録で user_extension が送られると `UnknownAttributeError`。
  `Decidim::User` モデルは 0.31.7↔0.32.1 で差分ゼロなので新規デグレではない
- `decidim-user_extension/app/views/decidim/account/show.html.erb` と
  `.../devise/registrations/new.html.erb` の全文上書き2件が 0.31 世代からドリフト
  （`data: { controller: ... }` 欠落、nickname の character-counter 欠落、`data-component="accordion"` が
  上流では `data-controller="accordion"`）。**上流の該当2ファイルは v0.31.7↔v0.32.1 で差分ゼロ**なので
  今回の upgrade で新規に壊れるものではない。別タスク推奨
- `app/packs/src/decidim/comments/comments.component.js:174` の `changeReportFormBehavior` 未定義（Phase 5.5 で解消）
- `lib/tasks/delete.rake:281` の `Decidim::Metric`（0.31.7 にも存在しない）
- `spec/shared/proposal_form_examples.rb:24-25, 250-254` の `create(:user_group, ...)` — factory は 0.31.7 にも無い。
  呼び出し元が `skip` 済みなのでテストは落ちない
- `.env.example` の `STORAGE_CDN_HOST` / `STORAGE_PROVIDER` はどこからも参照されていない

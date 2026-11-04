# Decidim 0.31 やり残しリスト

監査日: 2026-08-24 / 対象ブランチ: `upgrade/decidim-0.31`（HEAD `8afd020`, PR #857 Draft・main とコンフリクト中）
正本: `git show v0.31.0:RELEASE_NOTES.md`（559行。**v0.31.7 は81行の空テンプレなので使わない**）
関連: `decidim-0.31-upgrade-plan.md` / `decidim-0.32-upgrade-plan.md` / **`prd-infra-issues-2026-08.md`（本番インフラ課題）**

RELEASE_NOTES §1〜§5 の全項目、`config/` 全ファイル、一回きり rake、CDK 定時タスクを実ファイルで突合した結果。

---

## 🔴 P1: 本番切替前に必須

### 1-1. `config.load_defaults 6.1` のまま（§2.1 / §1.3-g 未実施）

`config/application.rb:19`。0.31 ブランチの10コミットは一度も application.rb を touch していない。

**経緯**: decidim 0.30 の generator は `load_defaults 7.0` → `6.1` に**書き戻していた**
（`v0.30.9:decidim-generators/lib/decidim/generators/app_generator.rb` の `load_defaults_rails61`）。
つまり 6.1 は 0.30 では正しい値。**0.31/0.32 の generator からはその強制が削除**され、上流は 7.2 へ上げる方針に転換した。
0.31 の RELEASE_NOTES は `sed -i "s/config\.load_defaults 6\.1/config\.load_defaults 7.2/g"` を指示しており、
cfj の値と**完全一致するので当たるはずだった**。

**なぜ落ちたか**: `decidim-0.31-upgrade-plan.md:68` が「`load_defaults 7.0` → `7.2`」と**元の値を取り違えて記載**しており、
実ファイルの `6.1` と照合されなかった。

**0.32 で悪化する**: 0.32 の sed は `7.2` → `8.1` を期待するため、`6.1` には当たらず**黙って no-op** する。
ここで直しておかないと 0.32 で 6.1 → 8.1 の2世代ジャンプになる。

→ 対応は **§付録 A「移行手順」** を参照（一時ピン留めが必須。単純に書き換えてはいけない）。

### 1-2. 一回きり rake **8本が未実行、記録もゼロ**（§3 全体）

`git grep "decidim:upgrade"` がリポジトリ全体で **0ヒット**。`docs/` も無変更。
（※「実行されていない証明」ではなく「記録が repo に残っていない」ことの確認。ECS exec の作業ログ側の確認を推奨）

DB マイグレーションだけ通して本番に出すと、**評価者ロール・ニックネーム・アクションログが壊れた状態**になる。
実行順とコマンドは **§付録 B「本番 runbook」** を参照。

### 1-3. `rails data:migrate` の手順化（対応済み・DEPLOYMENT.md には入れない）

`db/data_schema.rb` は `version: 2026_06_16_144141`（上流最新の
`decidim-forms/db/data/20260616144141_rename_answers_to_responses.rb` と一致）＝ローカルでは実行済み。
抜けると **Answer→Response 改名**と **user_groups 参照更新**が本番に適用されない。

※ `data_migrate (11.3.1)` gem は decidim-core 依存で導入済み、`decidim_core.data_migrate` initializer
（`v0.31.7:decidim-core/lib/decidim/core/engine.rb:233-238`）が engine の `db/data` を自動探索するので
アプリ側の追加設定は不要。

**対応（2026-09-08）**: Obsidian の `v0-31-0 ecs デプロイ手順.md` に、上流 §1.3 と同じ
**一回きり rake の後（最後）**の位置で記載した。

**`docs/DEPLOYMENT.md` には追記しない**（2026-09-08 判断）。同ファイルは一般開発者向けの
デプロイ手順であり、**decidim 本体のバージョンアップ手順を載せる場所ではない**。
アップグレード固有の手順は Obsidian 側の手順書に集約する。

### 1-4. `lib/tasks/delete.rake` の `destroy_all_metrics` が組織削除タスクを全滅させる（対応済み）

**対応日: 2026-09-08。** `lib/tasks/delete.rake:275` が `Decidim::Metric` を参照していた。
**0.31 にモデルが存在しない**ため `NameError` になり、`destroy_all` チェーン（`delete.rake:21`）に
組み込まれているせいで**テナントまるごと削除の運用タスクが途中で全部落ちていた**。

**当初は「タスクごと削除」を想定していたが、調査の結果それは不適切だった。**

- `decidim_metrics` テーブルは**残り続ける**。上流に `drop_table` する migration は無い
  （`create_decidim_metrics` は 0.31 にも健在）。0.30 時代の行が prd に残っている
- テーブルには**外部キーが一切無い**（張られている側・張っている側とも 0 件）ため
  `destroy_organization` は失敗しない。つまりタスクを消しても気づけず、
  **削除済みテナントの行が永久に残る**

→ モデル参照をやめ、テーブルが存在する場合のみ直接 SQL で消す形にした。
`organization.id.to_i` で組み立てているので SQL インジェクションは成立しない。

**残タスク**: 将来 `decidim_metrics` が上流で drop されたら、このタスクごと削除してよい。
`table_exists?` ガードがあるので、drop 後もエラーにはならない。

### 1-5. `api_user_query_hardening.rb` は 0.31 でも**まだ必要**（対応済み）

**追記日: 2026-09-08 / 対応済み。** `main` に PR #875（`cc5aa2fe`）がマージされた。GraphQL の
`user` クエリが引数なしでランダムな参加者を返すバグ（decidim/decidim#17468）のバックポート。

**当初「0.31 では上流に入っているので削除でよい」と判断したが、これは誤りだった。**
上流の修正はブランチにあるだけで、**まだどのリリースにも乗っていない**。

| | 状態 |
|---|---|
| `33aa27a7da`（#17468, 2026-08-13） | develop に merge |
| `983bd7b5c3`（#17484） | `release/0.31-stable` に merge・**未リリース** |
| `b6ba36863c`（#17483） | `release/0.32-stable` に merge・**未リリース** |
| **v0.31.7**（本ブランチが使用、tag 2026-07-30） | **ガード無し** |
| **v0.32.1** | **ガード無し** |

```ruby
# v0.31.7  decidim-core/lib/decidim/query_extensions.rb:56 ← 素通し
def user(id: nil, nickname: nil)
  Core::UserEntityFinder.new.call(object, { id:, nickname: }, context)
end
```

つまり削除するとバグが復活する。一方、元のバージョンガードは 0.30 系以外で `raise` するため、
残すと起動しない。そこで**ガード条件を「修正入りリリースを使い始めたら raise」に変更**した。

```ruby
# 変更前: 0.31.7 で起動不能
raise "..." if Gem::Version.new(Decidim::Core.version).segments.first(2) != [0, 30]
# 変更後: 0.30.9 も 0.31.7 も通り、0.31.8 以降で raise
raise "..." if Gem::Version.new(Decidim::Core.version) >= Gem::Version.new("0.31.8")
```

**残タスク**: decidim が **0.31.8 以降**（または修正入りの 0.32.x）に上がった時点で、
`config/initializers/api_user_query_hardening.rb` と `spec/requests/api_user_query_spec.rb`
を削除する。起動時 raise が知らせてくれる。

あわせて 0.31 追随のため以下も実施済み。

- spec の GraphQL context に `scopes:`（`Doorkeeper::OAuth::Scopes`）を追加。
  0.31 の `Decidim::Api::RequiredScopes#scope_authorized?` が `context[:scopes]` を
  無条件に参照するため、無いと `NoMethodError: undefined method 'scopes?' for nil` になる。
  **0.31 で GraphQL の spec を書く/直すときは常に必要。**
- `# rubocop:disable Lint/Void` を削除。0.30 の RuboCop では必要だったが、
  0.31 の新しい RuboCop では `Lint/RedundantCopDisableDirective` で逆に落ちる。

---

## 🟠 P2: 機能破損・データ不整合

### 2-1. `abaca00` が 0.31 の手順に無い cfj 独自対応を3件撤去している（leaflet は検証済み・問題なし）

0.31 コア更新コミット（2026-08-13 20:53、**分岐からわずか5時間後**）が、上流の指示にない削除を巻き込んでいる。
コミットメッセージは「Decidim 0.30.9 → 0.31.7 アップグレード（本体コア）」のみで**意図の記録がない**。

| 撤去されたもの | 何だったか | 現状 |
|---|---|---|
| `config/webpack/custom.js` の leaflet alias | `leaflet$` → `app/packs/src/decidim/leaflet_global.js`。「全バンドルで同一 Leaflet インスタンスを共有し plugin を保持する」ための cfj 独自対策 | **削除が妥当と確認済み（下記）** |
| `app/packs/src/decidim/index.js`（242行） | `2bd15fe`（2026-01-27）で意図的に置かれた shadow。上流 0.31.7 にも同名ファイルは健在 | 削除。**未検証** |
| expose-loader の `override: true` | `exposes: [{globalName: "$", override: true}, ...]` → `exposes: ["$", "jQuery"]` に巻き戻し | 巻き戻し。**未検証** |

#### leaflet の実機検証結果（2026-09-09・alias 削除で問題なし）

Docker で 0.31 を起動し、`db:seed` 済みの環境で alias 有無を A/B 検証した。**すべて alias 無しで正常動作**。

| 検証対象 | 結果 |
|---|---|
| 管理画面のナビゲーションマップ編集 | `L.PM` true、`.leaflet-pm-toolbar` 2個、Cancel / Finish / Remove Last Vertex ボタン実在 |
| 公開側のナビゲーションマップ | 画像レイヤー1・ポリゴン3本を描画。スクリーンショットで目視確認 |
| awesome map | タイル13・クラスタ4・マーカー7・レイヤー切替チェックボックス3。`markercluster` と `featuregroup.subgroup` が動作 |
| 会議マップ（core） | `.leaflet-container` として描画 |
| JS 実行時エラー | 0（CloudFront の DNS 解決失敗のみ。ローカル `.env` 由来） |

**なぜ alias が不要か**: プラグインを使う3バンドル（`decidim_admin_navigation_maps` /
`decidim_decidim_awesome_map` / `decidim_map_provider_default`）は**それぞれ Leaflet と必要な
プラグインを同一バンドル内に持つ自己完結構成**。バンドルをまたいでプラグインを共有する必要がない。

`.pm`（geoman）を使うのは `navigation_maps/admin/map_editor.js` **だけ**で、公開側の
`map_view.js` は使わない。管理画面では geoman を含むバンドルが最後に `window.L` を上書きするため
`L.PM` が生きている。

**注意（調査時の落とし穴）**: 手書きの検証ページでバンドルの読み込み順を強制すると
`window.L` が4つのインスタンスに分裂して `L.PM` が消える。これは**実在しない順序**であり、
実ページの挙動ではない。この誤りで2回、誤った結論を出した。**必ず実ページで確認すること。**

→ **対応済み（2026-09-09）**: 孤児化していた `app/packs/src/decidim/leaflet_global.js` と
`app/packs/entrypoints/application.js` の import を削除。削除後も上表の全項目が同一の結果。

### 2-2. `config/sidekiq.yml` の 0.31 追随（§4.1 / §4.2・対応済み）

**対応日: 2026-09-08（`af24fda0`）。** `- [metrics, 1]` を削除した。0.31 で Metrics 機能が
全廃され、`queue_as :metrics` を使うジョブは gem 全体に存在しない（grep で0件）。
投入されないキューを sidekiq が監視し続けている状態だった。実害は無いが §4.2 の明示要求。

**`delete_inactive_participants` キューは追加しない**（2026-09-08 判断）。
非アクティブアカウントの自動削除機能を使わない方針のため。CDK 側にも定時タスクを登録しない。

- このキューを使うのは `Decidim::DeleteInactiveParticipantsJob` と
  `Decidim::ProcessInactiveParticipantJob` の2つだけ
- ジョブを投入するのは `decidim:participants:delete_inactive_participants` の定時タスクのみ
- **将来この機能を有効化するなら、定時タスク登録とキュー追加を必ずセットで行うこと。**
  sidekiq は `:queues:` に無いキューを処理しないため、片方だけだとジョブが
  Redis に積まれたまま永久に実行されない（エラーも出ないので気づけない）
- 機能の内容: 既定365日ログインの無い参加者を自動削除。30日前・7日前に警告メール、
  期限までにログインすれば取消。`[500]` のように引数で日数変更可

CDK 側の `decidim:metrics:all` 削除は **`decidim-cfj-cdk` の `upgrade/decidim-0.31` ブランチ**
（`1b608c7`）で完了済み ✅。同コミットで `DECIDIM_COMMENTS_LIMIT` env と `CfEndpoint` SSM も撤去している。
**`main` には入っていない**ので、確認するときは必ずこのブランチを見ること
（`main` だけ見て「未対応」と誤判定した経緯あり・2026-09-08）。

### 2-3. `decidim.rb` のデッドコンフィグ 4件

| 行 | 設定 | 問題 |
|---|---|---|
| `:62` | `pdf_signature_service = "Decidim::Initiatives::PdfSignatureExample"` | 0.31 で **decidim-core に移動・改名**（`Decidim::PdfSignatureExample`）。かつ `decidim-initiatives` は**メタgem `decidim` に含まれず未インストール**。完全な dead config → 削除 |
| `:60` | `timestamp_service = "Decidim::Initiatives::DummyTimestamp"` | 同上。削除 |
| — | `machine_translation_service = "Decidim::Dev::DummyTranslator"` | `decidim-dev` は `:development, :test` グループのみ。`enable_machine_translations = false` なので現状無害だが、**本番で機械翻訳を有効化すると `NameError`** |
| `:58` | `sms_gateway_service = "Decidim::Verifications::Sms::ExampleGateway"` | generator の `--demo` 由来のダミー実装が本番設定に残存。SMS 認証を使わないなら削除 |

**注意**: `Decidim.configure` の `config` は `ActiveSupport::Configurable::Configuration`（`InheritableOptions` 派生）なので、
**存在しないキーに代入しても例外にならず黙って捨てられる**。「起動できた＝設定が効いている」ではない。

### 2-4. `production.rb` の未取り込み項目

| 項目 | 上流 | cfj 現状 | 影響 |
|---|---|---|---|
| `active_record.attributes_for_inspect = [:id]` | Rails 7.2 テンプレにあり | 無し | 🟠 **推奨追加**。未設定だと例外ログ／New Relic に全カラム値（メールアドレス等の個人情報）が出る |
| ログレベル | `ENV['RAILS_LOG_LEVEL']` で可変 | `:47` `config.log_level = :info` 固定 | 🟡 障害時に ENV でデバッグログに落とせない |
| `asset_host` | `ENV['RAILS_ASSET_HOST']` | `:28` コメントのまま | 🟡 |
| `cache_classes = true` | 7.1 で `enable_reloading` に非推奨化 | `:7` そのまま | 🟡 7.2 では deprecation なしで動く。0.32(Rails 8.1) 前に要対応 |

---

### 2-5. §5「Changes in APIs」の突合結果（2026-09-08・対応不要）

| 項目 | cfj への影響 |
|---|---|
| 5.2 `nicknamize` に organization 必須化 | **影響なし**。0.31 のシグネチャは `nicknamize(name, organization_id)` で両方必須（`decidim-core-0.31.7/lib/decidim/nicknamizable.rb:36`、`method(:nicknamize).parameters` で実測）。cfj の唯一の呼び出し `app/services/decidim/bulk_user_importer.rb:108` は `Decidim::User.nicknamize(local_part, organization.id)` で既に一致 |
| 5.1 / 5.4 / 5.6 / 5.7 OAuth・API 認証の変更 | 外部連携アプリの有無次第。本番で `SELECT count(*) FROM decidim_oauth_applications;` が0なら全項目非該当 |
| 5.8 / 5.9 Initiatives 署名フロー | **非該当**。`decidim-initiatives` はメタ gem に含まれず未インストール |

## 🟡 P3: 潜在的・掃除

- **`package.json` の `"shakapacker": "^8.3.0"`** — RELEASE_NOTES は `~8.3.0` を明示指示。
  `shakapacker.yml` の `ensure_consistent_versioning: true` により gem(8.3.0) と npm がズレると**起動時に例外**。
  現状 `yarn.lock` が 8.3.0 に固定しているので動くが、lock 更新時に 8.4.x を拾って壊れる
- **`config/shakapacker.yml` に `dev_server.live_reload: false` が欠落**（上流テンプレとの差分。開発体験のみ）
- **`.node-version` / `.nvmrc` が無い**、`package.json:4` の `engines.node` が `">=18.17.1"` のまま
  （Docker/CI は 22.14.0 に揃っている）
- **`config/cable.yml` と `production.rb:37-40` の ActionCable 設定が死に設定**
  （`application.rb:7-9` で `action_cable/engine` をコメントアウトしている。0.30 からの継続で 0.31 リグレッションではない）
- **`config/locales/ja.yml:137` の `metrics:` 翻訳ブロック**が残存
- **`.env.example` に `STORAGE_PROVIDER=s3`** と書かれているが、`config/storage.yml` に `s3:` エントリは無く
  `production.rb:35` は `:amazon` 決め打ち。**誤解を招くので修正**
- `config/initializers/redis.rb:2` の `Redis.exists_returns_integer = true` は redis 4.8.1 で no-op（死に設定）。
  ただし **0.32 で sidekiq 7 化 → redis 5.x になると NoMethodError** になるので、そのとき削除
- `Decidim::Api::Schema.max_complexity = 100_000` を `to_prepare` 内で直接代入している。
  0.31 の正式口は `Decidim::Api.schema_max_complexity`（ENV `API_SCHEMA_MAX_COMPLEXITY`）。動くが置換推奨
- HERE 静的地図 URL が `.../mia/1.6/mapview`（deprecated）。0.31 上流デフォルトは v3。
  実運用が `cfj_osm` なら影響なし
- LINE シェアの `icon = "line-fill"` は remixicon にも `app/packs/images/` にも存在せず空アイコン表示のはず
  （0.31 固有問題ではない）。※`icon_color` を削った点は 0.31 で `SocialShareServiceManifest` から
  当該属性が削除されたため**正しい**

---

## ✅ 実施済み・非該当と確認できたもの

### 実施済み
- **`Rails.application.secrets` 全廃** — main の6ファイル → 0.31 ブランチで **0件**。`config/secrets.yml` も削除済み（244行）
- 旧 `secrets.yml` が読んでいた ENV 名と 0.31 `core.rb` の `Decidim::Env` デフォルトが**完全一致**
  → **ECS タスク定義の環境変数はそのままで実効値が変わらない**
- Ruby 3.3.11 / Node 22.14.0（Docker・CI とも）
- Gemfile の 0.31.7 ピン、`bundle update decidim`、`decidim:upgrade` + `db:migrate`（0.31系 migration 41本取込）
- shakapacker 8.3.0 の gem/npm 整合、binstub 2本の 0.31 形式化
  （`require "decidim/shakapacker/shakapacker"`）
- valuator→evaluator の**コード追従は取りこぼしなし**（`app/ config/ spec/ lib/ decidim-user_extension/` で
  `valuator` 0件。残存は `db/migrate` と `db/schema.rb` のインデックス名のみで実害なし）
- answer→respond の**コード追従も取りこぼしなし**（`publish_answers_controller_override.rb` →
  `publish_responses_controller_override.rb` にリネーム済み）
- `cde647c` の mobile_logo 再配線（0.31 の `OrganizationForm`/`UpdateOrganization` 統合に追従）
- `8afd020` の `show_exceptions = :rescuable`（Rails 7.1+ Symbol API の先取り。良い判断）
- **2024年7月のピン留めは完全にクリーンアップ済み** — `use_cookies_with_metadata` /
  `cookies_same_site_protection` / `urlsafe_csrf_tokens` の grep ヒット 0

### 非該当（確認済み）
- **§3.7 AWS assets storage — 上流テンプレを採用しないのが正解**
  上流 0.31 テンプレは `public: <%= Decidim::Env.new("AWS_PUBLIC", "true") %>` で**デフォルト true**。
  cfj は `blockPublicAccess: BLOCK_ALL`（`decidim-cfj-cdk/lib/s3-stack.ts:19`）+ CloudFront OAC +
  `resolve_model_to_route = :rails_storage_proxy` なので、取り込むと壊れる。commit `80cc0b1` の撤回判断は**妥当**。
  `Decidim.storage_cdn_host` は `Decidim::Env` を直読みし ENV 名は 0.30 と同一なので配信経路も不変。
  `Decidim.storage_provider` は上流のどこからも参照されていない
- **§3.7 の CSP 追記も不要** — `config/initializers/decidim.rb:81-88` の `content_security_policies_extra` が
  全ディレクティブ `["*"]` のため（※これ自体は別途セキュリティ課題。下記参照）
- **§5.1/5.6/5.7 API 認証系** — `DECIDIM_API_FORCE_API_AUTHENTICATION` / `DECIDIM_API_JWT_SECRET` は任意機能
- **§5.2 `nicknamize` の organization 必須化** — 0.31 ブランチに使用箇所ゼロ。加えて上流の
  `def nicknamize(name, organization_id)` は **v0.30.9 時点で既に2引数**（0.31/0.32 も同一）
- **§5.3/5.4/5.5 OAuth 拡張・scope `public`→`profile`** — cfj に Doorkeeper / oauth_application 関連コードなし。
  §5.4 は **Decidim が認可サーバ側**の話で、cfj の LINE / CityOS は**クライアント側**の OmniAuth strategy なので無関係。
  ※ただし OAuth アプリは `/system` から DB 登録されるため、**本番の `decidim_oauth_applications` が空かの確認は必要**
- **§5.8/5.9 Initiatives 署名ワークフロー** — `decidim-initiatives` は 0.31.7 のメタgem `decidim` に含まれず
  Gemfile.lock にも存在しない＝未インストール
- **§2.4 Meetings Polls 非推奨** — cfj のアプリコードに参照なし
- `config/` に新規必要ファイルの欠落なし（0.31 新設の `elections_initializer.rb` /
  `initiatives_initializer.rb` は `--demo` 専用かつ両モジュール未インストール）
- `decidim-core` 側の `new_framework_defaults_7_0.rb` は 0.31.7 で削除されたが、**中身は全行コメント**だったので
  挙動変化なし

### 0.31 とは無関係だが要検討
- **CSP が実質無効化されている** — `config/initializers/decidim.rb:81-88` が全ディレクティブ `["*"]`。
  `script-src "*"` は XSS 防御をほぼ放棄している。0.31/0.32 と切り離して別タスクで検討すべき

---

## 付録 A: `load_defaults` 6.1 → 7.2 の移行手順

**【2026-08-24 全面改訂】** 4方向の詳細調査（上流実ソース読解 + Docker 実測）の結果、
当初想定した重大リスク（キャッシュ形式・サニタイザ・DB暗号化）は**いずれも実体がない**と判明。
本節はその実測結果に基づく。

### A-0. 前提の転換: cfj は upstream より「古い」defaults で動いている

decidim 0.31.7 は **Rails 7.2 defaults 前提で開発されている**。決定的な証拠:

```ruby
# decidim-admin/app/jobs/decidim/admin/newsletter_job.rb:9
self.enqueue_after_transaction_commit = :never
```

upstream は 7.2 の挙動変化を認識し、唯一の例外を明示的に潰している。
`decidim-generators` は `Rails::Generators::AppGenerator` を継承するため、
upstream の development_app / test dummy は 7.2 defaults で CI が回っている。

→ **7.2 化は「未知の領域に踏み込む」のではなく「upstream の想定に追いつく」方向。**

### A-1. 🟢 消滅したリスク（decidim が engine initializer で上書きしている）

| 当初の懸念 | 実際 | 根拠 |
|---|---|---|
| キャッシュ形式変更でロールバック時に全ログアウト | **decidim が `cache_format_version = 7.0` に固定**。cfj は `load_defaults 6.1` でも既に 7.0 形式で書いている。`load_defaults` を上げても1ビットも変わらない | `decidim-core/lib/decidim/core/engine.rb:279-283`（0.32.1 は `:262`） |
| サニタイザ HTML5 化でコンテンツ崩れ | **decidim が `sanitizer_vendor = Rails::HTML4::Sanitizer` に固定**。ActionView が値を読むのは `after_initialize`（`action_view/railtie.rb:49-53` → `finisher.rb:93-94`）なので railties_initializers 段の decidim が勝つ | `engine.rb:289-291`（0.32.1 は `:269-271`） |
| DB 暗号化データが復号不能 | **0.31.7 は SHA1 をハードコード**。`config.active_support.hash_digest_class` も `key_generator_hash_digest_class` も読まない | `decidim-core/lib/decidim/attribute_encryptor.rb:23`、`newsletter_encryptor.rb:16`、`initiatives/data_encryptor.rb:11` |
| `cookies_serializer` :marshal→:json 移行 | **cfj は既に `:json` 明示済み**＝差分ゼロ | `config/initializers/cookies_serializer.rb:7` |

さらに Rails の cache serializer は全形式を読める設計（`serializer_with_fallback.rb` の `load` を
全シリアライザが共有し、ペイロードの先頭バイトで振り分ける）ことも実ソースで確認済み。

### A-2. 🔴 本物のリスク①: YJIT のメモリ増（最優先）

`load_defaults 7.2` の `self.yjit = true`（`configuration.rb:324` → `finisher.rb:231-233`）。
**A〜F の中で唯一「正しさ」ではなく「リソース収支」を変える項目。**

現状の閾値配置が既に歪んでいる:

```
PWK reap:        2764.8 MiB   (config/puma.rb:27 ram=3072 × percent_usage 0.9)
ECS scale-out:   2867.2 MiB   (memory 4096 × 目標70%)
ECS OOM kill:    4096   MiB
```

→ **PWK が先に発火するため、メモリ由来のスケールアウトは事実上デッドコード。**
逼迫時に「台を増やす」のではなく「worker を殺す」動作になっている。

加えて **`config/puma.rb:53` の `preload_app!` がコメントアウト**されているため CoW 共有が効かず、
YJIT のコード領域（`--yjit-exec-mem-size` 既定 128MiB）が **4 worker 分まるごと加算**される
（`WEB_CONCURRENCY: '4'` は `decidim-cfj-cdk/lib/decidim-stack.ts:189`）。

刈られたときの連鎖: 60秒ごとに worker TERM → `pre_term` で Slack へ**同期 HTTPS POST**
（`config/puma.rb:32-35`、`slack-ruby-client` の timeout 既定 `nil` = 無制限）→
preload 無効なので再起動 worker は Decidim をフルロード（数十秒）→ 実効容量25%減 →
CPU 上昇 → スケールアウト → 新タスクも同じ挙動。

**sidekiq 側はより確実に踏む**: dev/staging は memory **1024 MiB**、PWK のような安全弁なし、
`desiredCount: 1` 固定でオートスケールなし（`decidim-stack.ts:341-368`）。
Sidekiq 6.5 は `super_fetch` 非搭載なので **OOM kill で実行中ジョブが失われる**。

> **【2026-08-25 実測完了】** 本番の実測により、**YJIT 以前に既存の問題があることが判明**した。
> 詳細は **`prd-infra-issues-2026-08.md`** を参照。要点:
> - Puma 合計 RSS の **p95 = 2741 MiB / max = 2764.73 MiB**（PWK 閾値 2764.8 とほぼ一致）
>   → メモリが reaper に叩き落とされている状態。**7日で9回の OOM reap**
> - PWK は RSS を単純合計するため約 160〜180 MiB 過大計上。**ECS 実測は 64.2%** で 1466 MiB 余っている
>   → `ram = 3072` が実態（4096）と乖離した誤設定
> - **sidekiq にメモリリーク**。838 MiB → 約86 MiB/日で上昇 → 1910 MiB(93.2%) で OOM 死。
>   デプロイなしの再起動を7日で4回確認。Sidekiq 6.5 は super_fetch 非搭載で**実行中ジョブが消失**
> → **YJIT は現状不可**で確定。ただし原因は YJIT ではないので、先に上記を直せば余地が生まれる。

#### ベースラインは既に取得可能

`config/puma.rb:31` の `reaper_status_logs = true` により**60秒ごとに合計 RSS がログ出力済み**:

```
CloudWatch Logs: <stage>-decidim-serviceLogGroup（prefix: app）
fields @timestamp, @message | filter @message like /PumaWorkerKiller: Consuming/ | sort @timestamp desc
```

**p95 > 2400 MiB なら YJIT 有効化は不可。**

#### 対応

切替と同時に `config.yjit = false` を入れる。有効化は別デプロイで、かつ以下を先に済ませてから:
1. `config/puma.rb:27` の `ram = 3072` → **3600**（閾値 3240 = コンテナ4096の79%）。
   PWK が ECS スケールアウト(2867)より**後**に発火する正しい順序になる
2. `config/dev.json` / `config/staging.json` の `ecs.sidekiq.memory` を **1024 → 2048**（prd と揃える）
3. `preload_app!` 有効化の検討（**単独の変更として検証**すること）
4. `SlackChatMessenger` にタイムアウト設定

### A-3. 🟠 本物のリスク②: `key_generator_hash_digest_class` SHA1→SHA256

**設定名の区別が重要**（`load_defaults 7.0` は両方同時に SHA256 にする）:

| 設定 | 0.31.7 の暗号化 | 0.32 の暗号化 | Cookie / ActiveStorage |
|---|---|---|---|
| `key_generator_hash_digest_class` | 無関係 | 無関係 | **これが効く** |
| `hash_digest_class` | 無関係（SHA1 ピン） | **これで決まる** | 無関係 |

Docker 実測（Rails 7.2.3 + Devise 4.9.4、`secret_key_base` 固定）で確認した鍵の変化:

| 導出対象 | 判定 |
|---|---|
| signed cookie / encrypted cookie / `active_record/signed_id` / `ActiveStorage` | **変化** |
| Devise `key_for(:reset_password_token)` / `digest(...)` | **不変** |
| decidim の SHA1 ピン鍵（`"attribute"`） | **不変** |

**Devise が不変な理由**: `devise/rails.rb:43-51` の initializer が
`active_support.set_key_generator_hash_digest_class` の `after_initialize` ブロックより**先**に走り、
`KeyGenerator#initialize`（`key_generator.rb:33`）が**生成時点**のクラス既定 SHA1 を捕まえて固定するため。
→ パスワードリセット・招待・確認・ロック解除トークンは**全て無傷**。
※これは実装順序に依存した幸運なので、実 cfj での再確認が必要（A-6 の検証手順）。

#### 影響するもの（🟠 2件）

**① remember-me の失効**
`devise/controllers/rememberable.rb:29` が `cookies.signed[...]`。鍵が変われば `nil` →
`strategies/rememberable.rb:15` の `valid?` が false → strategy 自体がスキップされ自動ログインされない。
`Decidim.enable_remember_me` は既定 true（`core.rb:513-518`）で cfj 未上書き＝**実際に影響する**。
なお検証失敗は例外ではなく nil（`cookies.rb:635` の `verified`）なので 500 にはならない。

**② 既存メール内の添付ファイルリンクが全て 404** ← 見落としやすい
- `production.rb:59` `resolve_model_to_route = :rails_storage_proxy`
  → URL は `/rails/active_storage/blobs/proxy/<signed_id>/<filename>`
- `production.rb` に **`urls_expire_in` の設定なし**＝**無期限**
  （`development.rb:63` にはあるが dev のみ。decidim が設定する `service_urls_expire_in` は別物）
- `ActiveStorage.verifier` は `app.message_verifier("ActiveStorage")`（`activestorage/lib/active_storage/engine.rb:136-140`）
  ＝ `Rails.application.key_generator` 経由

→ **運用開始以来の全メールに埋め込まれた添付リンクが、切替の瞬間に一斉に 404 になる。**

ただし **DB 保存の本文は安全**: `BlobParser`（`content_parsers/blob_parser.rb:70`）が保存時に
signed_id を GlobalID へ正規化し、`BlobRenderer` が表示時に毎回 URL を再生成するため
再レンダリングで復旧する。

#### 対応: 切替時は SHA1 に据え置く

```ruby
config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1
```

`activesupport/lib/active_support/railtie.rb:136` は `if klass = ...` なので明示すれば SHA1 が適用される。

**据え置く理由:**
1. ブルーグリーン切替では Redis が空でセッションが全消失し「ログインできない」問い合わせが多発する。
   そこに remember-me 失効が重なると**切替起因か digest 起因か切り分け不能**になる
2. メール内添付リンクの失効件数が事前に測れない
3. セキュリティ上の緊急性がない（PBKDF2 の PRF としての HMAC-SHA1 は NIST SP 800-132 準拠、実用的攻撃なし）

**後日 SHA256 に上げるときの手順**は A-5 を参照。

### A-4. 🟠 本物のリスク③: SMTP `read_timeout` 5秒 → 重複送信

`action_mailer.smtp_timeout = 5`（7.0）。`actionmailer/lib/action_mailer/railtie.rb:55-60` は
`smtp_settings[:open_timeout] ||= smtp_timeout` なので、**明示指定があればそちらが勝つ**。
cfj の `production.rb:80-89` には明示がないため 30秒/60秒 → **5秒/5秒**（read が12倍厳しくなる）。

機序: SMTP で最も遅いのは `DATA` 送信後の `250 Ok` 応答で、SES はここでメッセージを受理・採番する。
5秒で打ち切ると **「SES は受理済みだがクライアントは失敗と判断」**。そこから:
`raise_delivery_errors` は production 既定 true → 例外 →
`NewsletterDeliveryJob:11` は `deliver_now` → Sidekiq が最大25回リトライ →
**同じ受信者に同じメールが再送**（ユーザー単位の冪等ガードなし）。

接続確立は SES の VPC Interface Endpoint 経由（`decidim-cfj-cdk/lib/network.ts:100-108`）で
数ミリ秒なので `open_timeout` 5秒は問題なく、むしろ fail-fast は利点。

#### 対応: `read_timeout` だけ伸ばす（コストゼロ）

```ruby
# config/environments/production.rb の smtp_settings に追加
open_timeout: Decidim::Env.new("SMTP_OPEN_TIMEOUT", 5).to_i,
read_timeout: Decidim::Env.new("SMTP_READ_TIMEOUT", 30).to_i,
```

### A-5. 後日 SHA256 に上げるときの手順（0.31 安定後の独立リリース）

**① Rails 公式のクッキーローテータ**（`guides/source/upgrading_ruby_on_rails.md:533-565` に文書化）
decidim / Devise を一切変更せずに remember-me を救える:

```ruby
# config/initializers/cookie_rotator.rb
Rails.application.config.after_initialize do
  Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
    salt_enc = Rails.application.config.action_dispatch.authenticated_encrypted_cookie_salt
    salt_sig = Rails.application.config.action_dispatch.signed_cookie_salt
    kg = ActiveSupport::KeyGenerator.new(
      Rails.application.secret_key_base, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1
    )
    cookies.rotate :encrypted, kg.generate_key(salt_enc, ActiveSupport::MessageEncryptor.key_len)
    cookies.rotate :signed,    kg.generate_key(salt_sig)
  end
end
```

**② ActiveStorage 側**（公式手順としては未文書化・**要検証**）
`message_verifiers.rotate` は verifier 生成前に登録が必要で、`ActiveStorage.verifier` は
`after_initialize` で作られるため `before_initialize` なら間に合う:

```ruby
config.before_initialize do |app|
  legacy = ActiveSupport::CachingKeyGenerator.new(
    ActiveSupport::KeyGenerator.new(app.secret_key_base, iterations: 1000,
                                    hash_digest_class: OpenSSL::Digest::SHA1)
  )
  app.message_verifiers.rotate(secret_generator: ->(salt, **) { legacy.generate_key(salt) })
end
```

**③ ローテータの撤去期限を決める。** remember-me の `remember_for`（既定2週間）+ 余裕で
1か月後に削除するチケットを切る。残し続けると SHA1 鍵の Cookie を受け入れ続け移行の意味が薄れる。

**④ 0.32 と同時に上げる場合**は `hash_digest_class` も SHA256 になり
`bin/rails decidim:upgrade:encryption` が必須。
**ただしこのタスクは `Decidim::Authorization` しか再保存しない。**
`Decidim::Organization` の `smtp_settings["encrypted_password"]` と `omniauth_settings`
（`base_organization_form.rb:99,112`）は対象外なので `Decidim::Organization.find_each(&:save)` も必要。

### A-6. 切替直後に必ず走らせる検証

```bash
# ① decidim の固定が効いているか（これで大勢が決まる）
bin/rails runner 'puts ActionView::Helpers::SanitizeHelper.sanitizer_vendor'   # => Rails::HTML4::Sanitizer
bin/rails runner 'puts ActiveSupport::Cache.format_version'                    # => 7.0
bin/rails runner 'puts ActiveStorage.variant_processor'                        # => :mini_magick

# ② 鍵が据え置かれているか
bin/rails runner 'puts ActiveSupport::KeyGenerator.hash_digest_class'          # => OpenSSL::Digest::SHA1

# ③ Devise トークンが不変か（順序依存の罠。SHA256 に上げるときに必須）
bin/rails runner 'p Devise.token_generator.digest(Decidim::User, :reset_password_token, "fixed-sample")'

# ④ 暗号化データが読めるか
bin/rails runner 'a = Decidim::Authorization.where.not(metadata: nil).first; p a&.metadata'
bin/rails runner 'o = Decidim::Organization.first; p Decidim::AttributeEncryptor.decrypt(o.smtp_settings["encrypted_password"]) rescue p $!'

# ⑤ YJIT が無効か
bin/rails runner 'p RubyVM::YJIT.enabled?'                                     # => false
```

### A-7. 🟢 何もしなくてよいと確定したもの

| 項目 | 判定根拠 |
|---|---|
| `enqueue_after_transaction_commit`（7.2） | cfj の `perform_later` は `decidim_override.rb:124` の `PurgeComponentCacheJob` 1件のみ。現状はコミット前に purge が走り**別リクエストが旧設定で再充填する競合**があるため、**むしろ改善**。※`NewsletterJob` の `:never` は upstream の意図なので絶対に触らない |
| `postgresql_adapter_decode_dates`（7.2） | `t.date` は19カラムあるが、cfj の生 SQL は `DELETE` / `pluck(:resource_id)`（整数）/ テキスト正規化のみ。upstream のランタイム生 SQL も6箇所で、日付式2箇所は `ORDER BY` 専用（`participatory_process.rb:95`）と `::text` 明示キャスト（`budgets/project.rb:133`） |
| `button_to_generates_button_tag`（7.0） | **cfj に `button_to` が0件**。SCSS に `input[type=...]` セレクタも0件。upstream の `confirm.js:117-119` は `button`/`input` 両方を見ている |
| `apply_stylesheet_media_default`（7.0） | 表側は `_head.html.erb:33-34` が **`media: "all"` 明示済み**で変化なし。メールは premailer が media 属性を見ずにインライン化。※カンファレンス修了証の印刷 CSS は**現状死んでおり 7.2 で正常化**する（是正） |
| `default_headers` の変更（7.0/7.1） | nginx に `add_header` 0件、CloudFront の ResponseHeadersPolicy は非prdの `X-Robots-Tag` のみ、cfj アプリ側も0件＝**競合なし**。`Referrer-Policy` は「外部へ出るとき」の制御で流入リファラには無影響。かつ Chrome 85+/Firefox 87+ が既定で同値 |
| `raise_on_open_redirects`（7.0） | cfj 本体に外部 `redirect_to` 0件。**ただし decidim_awesome に1件あり（A-8）** |
| `default_column_serializer` / `encrypts` / `attr_readonly` / `after_commit`（7.1） | cfj 本体・fork gem 7本すべて0件 |
| `add_autoload_paths_to_load_path`（7.1） | `lib` は `paths.add "lib", load_path: true` で常時 `$LOAD_PATH` |
| `validate_migration_timestamps`（7.2） | cfj 最大 `20260805075273` < 現在時刻 |
| Cookie 同意（`decidim-consent`） | `data_consent/consent_manager.js:24` の js-cookie 平文＝**再同意ダイアログは出ない** |
| `Decidim::PrivateDownload` のメールリンク | `private_download.rb:25` が `secret_key_base` を生の secret として直接使用＝key_generator 非経由 |

### A-8. 🔴 付随して発見: decidim_awesome のオープンリダイレクト

`app/controllers/decidim/decidim_awesome/required_authorizations_controller.rb`

```ruby
15:  redirect_to redirect_url if user_signed_in? && service.granted? && ...
24:    path = params[:redirect_url] || request.referer   # 完全にユーザー制御可能な絶対URL
28:    else path                                          # そのまま redirect_to へ
```

- ルートは `engine.rb:20` で**無条件登録**
- cfj の `force_authorizations` は未設定＝既定 `{}` で `:disabled` ではないため
  `access_authorization_service.rb:24` の `granted?` が true を返し**必ず15行目に入る**
- `raise_on_open_redirects = true` で **`UnsafeRedirectError` = 500**

**7.2 化と無関係に、現時点で存在する脆弱性**（`?redirect_url=https://evil.com` で任意サイトへ誘導可能）。
`allow_other_host: true` を付けるのは**誤り**（脆弱性を温存する）。
同 gem の `not_found_redirect.rb:32` が既に「`URI(referer)` から `uri.path` だけ抽出」という
正しい実装をしているので流用する。**upstream の decidim-ice へ報告する価値もある。**

### A-9. `config/application.rb` の最終形

```ruby
config.load_defaults 7.2

# --- 一時ピン（0.31 本番切替の安定後に別リリースで外す）---

# [1] YJIT。7.2 defaults の中で唯一「リソース収支」を変える項目。
#     PWK 閾値(2764.8MiB)が ECS スケールアウト(2867.2MiB)より先に発火する現状の配置と、
#     preload_app! 無効による CoW 非共有のため、メモリ増が worker 刈りの連鎖を招きうる。
#     有効化は PWK ram を 3600 に上げ、sidekiq memory を 2048 に揃えてから別デプロイで。
config.yjit = false

# [2] 署名 Cookie の鍵導出。SHA256 にすると
#     ① remember-me が全失効（Devise のトークンは初期化順序により不変）
#     ② 過去メールに埋め込まれた ActiveStorage proxy URL が一斉に 404（urls_expire_in 未設定＝無期限）
#     ブルーグリーン切替と同時にやると切り分け不能になるため据え置く。
#     解除時は config/initializers/cookie_rotator.rb を併用（付録 A-5）。
config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1
```

`config/environments/production.rb` の `smtp_settings` に追加（ピンではなく恒久設定）:

```ruby
open_timeout: Decidim::Env.new("SMTP_OPEN_TIMEOUT", 5).to_i,
read_timeout: Decidim::Env.new("SMTP_READ_TIMEOUT", 30).to_i,
```

別コミットで（Rails 7.2 推奨、7.2 化と独立に価値がある）:

```ruby
config.active_record.attributes_for_inspect = [:id]   # 例外ログ/New Relic への個人情報流出防止
```

### A-10. 切替後の監視

| メトリクス | 取得元 | 閾値・アクション |
|---|---|---|
| **Puma 合計 RSS** ★ | CloudWatch Logs `filter @message like /PumaWorkerKiller: Consuming/` | 切替前 p95 を必ず取得。p95 > 2400 MiB なら YJIT 有効化不可 |
| PWK reap 回数 | 同ログ `/Out of memory/` + Slack 通知 | > 1回/時 → 即ロールバック |
| **sidekiq MemoryUtilization** ★ | CloudWatch ECS SidekiqService | p95 > 75%（dev/staging は母数1024MiB）→ 2048 へ引き上げてから切替 |
| sidekiq OOM kill | ECS Service Events / exit 137 | **1回でもアウト**（Sidekiq 6.5 は super_fetch なしで実行中ジョブ消失） |
| ALB 5XX / TargetResponseTime | CloudWatch ALB | 5XX が平常の2倍 → ロールバック |
| `Net::ReadTimeout` | sidekiq ログ | 1件でも出たら `read_timeout` を再調整 |
| ニュースレター重複 | `decidim_newsletters.total_deliveries` vs `total_recipients` | `deliveries > recipients` → 重複送信発生 |
| **通知メール件数** | SES Send / `decidim_notifications` | **増加は正常**。7.2 化で今まで落ちていた通知（提案公開・回答通知等）が届くようになるため。障害と誤判定しないこと |
| `ActiveJob::DeserializationError` | sidekiq ログ | 切替後**減るはず**（改善効果の直接指標） |

## 付録 B: 本番 runbook（一回きり rake の実行順）

### 事前確認（本番 DB）

```sql
-- 3.1 の要否
SELECT count(*) FROM decidim_participatory_process_user_roles WHERE role='valuator';
-- 3.2 の衝突チェック（衝突があれば fix_nickname_uniqueness を併用）
SELECT lower(nickname), count(*) FROM decidim_users GROUP BY 1 HAVING count(*)>1;
-- 3.4 の要否（0件なら実行不要）
SELECT count(*) FROM decidim_authorizations WHERE name='sms';
-- 3.6 のメール送信規模
SELECT count(*) FROM decidim_user_groups;
-- §5 の要否（空なら §5 全項目が非該当で確定）
SELECT count(*) FROM decidim_oauth_applications;
```

### 実行順

```bash
# ── 0) マイグレーション ───────────────────
bin/rails db:migrate
bin/rails data:migrate          # ★ 手順書に無い。追加必須（1-3）

# ── 1) メール送信を伴わない安全なもの ────────
bin/rails decidim:upgrade:decidim_update_valuators
bin/rails decidim:upgrade:decidim_action_log_valuation_assignment
bin/rails decidim:upgrade:decidim_paper_trail_valuation_assignment
bin/rails decidim_surveys:upgrade:fix_survey_permissions   # ※namespace は decidim: ではない
bin/rails decidim:upgrade:fix_action_log
bin/rails decidim:upgrade:clean:invalid_private_exports
bin/rails decidim:upgrade:fix_nickname_casing
# 衝突があった場合のみ（RELEASE_NOTES 未記載）
bin/rails decidim:upgrade:fix_nickname_uniqueness

# ── 2) ★メール送信を伴う。切替タイミングを制御 ──
bin/rails decidim:upgrade:user_groups:remove

# ── 3) 条件付き ──────────────────────
bin/rails decidim:verifications:revoke:sms                    # SMS 認証の実データがある場合のみ
bin/rails decidim:upgrade:fix_deleted_private_follows         # 非公開スペースがある場合（0.31.x 追加・RELEASE_NOTES 未記載）
bin/rails decidim:upgrade:clean:remove_private_exports_attachments  # 任意
```

§1 のタスクはすべて冪等（再実行安全）。§3.1 の3本は `db:migrate` 完了が前提
（`20260805075261〜75263` のリネームマイグレーションに依存）。

### ⚠️ `user_groups:remove` の重大な注意

**RELEASE_NOTES §3.6 の表は不完全**。実 `user_groups_migration.rake` の `remove` は**6タスクの連鎖**で、
表に載っていない **`perform_patches_on_emails` が先頭**にある。上流ソース実読:

```ruby
password = Random.alphanumeric(15)
group.password = password
...
Decidim::UserGroupMailer.notify_user_group_patched(group, user, password).deliver_later
```

→ **メンバー全員に平文パスワードがメール送信される**（対象は `extended_data @> {group: true, patched: true}`
かつ `encrypted_password: ""` のグループのみ）。さらに `send_reset_password_instructions` と
`send_user_group_changes_notification_to_members` も送信する。

**したがって、メンテ明け・新コードが本番で稼働した直後に実行すること。** 実行が早すぎるとユーザーが
旧UIに戻ってきて混乱する。事前にグループ件数・宛先メール・SES の送信レート/サンドボックス状態を確認すること。

送信を避けたい場合は、メール送信3タスクをスキップして
`transfer_user_groups_authorships` / `fix_user_groups_action_logs` / `remove_groups_notifications`
の3つのみ個別実行する選択肢がある（**後2つを飛ばすと管理画面のアクティビティログと通知一覧が例外で落ちる**ため必須）。

---

## 付録 C: main → 0.31 の forward-port バックログ（17ファイル）

PR #857 が CONFLICTING な原因。分岐後に main へ入った未反映の作業。

| 塊 | ファイル | 注意点 |
|---|---|---|
| CityOS OmniAuth v1.5.2 化 | `config/initializers/omniauth_cityos_dcp.rb`, `omniauth_cityos_button_override.rb`, `lib/decidim/cfj/cityos_omniauth_configuration.rb`, `lib/tasks/cityos_omniauth.rake`, `config/locales/cityos_dcp_login.{ja,en}.yml`, `app/packs/stylesheets/decidim/cfj/login.scss` | initializer が `Rails.application.secrets[:omniauth]` を使用 → **0.31 で全廃済み。書き換え必須** |
| アンケート並び替え | `app/models/decidim/cfj/survey_order.rb`, `app/commands/decidim/cfj/reorder_surveys.rb`, `config/initializers/surveys_ordering_override.rb`, `app/views/decidim/surveys/admin/surveys/index.html.erb`, `db/migrate/20260817120000_create_decidim_cfj_survey_orders.rb`, `config/locales/survey_ordering.{ja,en}.yml` | override が「**v0.30.9 時点の core をコピー**」と自認。0.31 で再コピーが要る |
| 集計グラフ修正 (#862) | `config/initializers/publish_answers_helper_override.rb` | 0.31 で `PublishAnswersHelper` → **`PublishResponsesHelper`** に改名。要リネーム |
| — | `config/secrets.yml` | 0.31 ブランチでは削除済み。**コンフリクト確実**。main 側の変更内容を ENV へ移す |

### あわせて: omniauth-cityos-dcp（2026-09-10 検証・対応保留）

**方針決定（2026-09-10）: 今は対応しない。gem 側の更新を待つ。**

#### 現状

`main` は `tag: "v1.5.2"` で**有効**。0.31 ブランチは `abaca001` でコメントアウトされ
`tag: "v1.4.0"` のまま。**Gemfile 差分で無効化されているのはこの gem だけ**
（fork モジュール5本はすべて 0.31 ブランチで有効）。

#### 「Gemfile を戻せば有効になる」は誤り（実機検証済み）

`config/initializers/omniauth_cityos_dcp.rb` のコメントにある
「Gemfile に gem を戻せばそのまま有効になる」は**間違い**。実際に試した結果:

| 手順 | 結果 |
|---|---|
| Gemfile のコメント解除 + v1.5.2、`bundle install` | 成功。lock は9行追加のみ、他 gem は不動 |
| イメージ再ビルド + コンテナ再作成 | 起動 OK |
| gem ロード | `true` / version 1.5.2、strategy 定数も定義済み |
| 組織に設定投入 → `enabled_omniauth_providers` | `[:developer, :cityos_dcp_login]`、`missing_keys` は空 |
| **`/users/sign_in`** | **500** |

```
ActionView::Template::Error
  undefined method `user_cityos_dcp_login_omniauth_authorize_path'
```

**原因**: Devise の omniauth ルートは `Decidim.config.omniauth_providers` に登録された
プロバイダにしか生成されない。0.31 ブランチの `config/initializers/decidim.rb:84-90` は
`line_login` しか merge していない。

0.30 では `config/secrets.yml:150-162` の `cityos_dcp_login` ブロックから
Decidim が `omniauth_providers` を組み立てていたため、**secrets に書くだけでルートも
生成されていた**。0.31 の secrets 廃止でこの経路が切れ、移行されていない。

組織単位で有効化しても `tenant_enabled_providers` が merge するので
`enabled_omniauth_providers` には載るが、**ルートは生成されない**ためボタン描画で落ちる。

#### gem 側の責務だったのは事実

v1.4.0 の `engine.rb` は gem 自身の `secrets.yml` を
`Rails.application.secrets[:omniauth][:cityos_dcp_login]` に**注入**していた。
これがプロバイダ登録とルート生成を成立させていた。他に view パス追加・locales・
helper prepend・アイコン登録も engine が担当。

v1.5.0〜v1.5.2 でこれらを全廃し、strategy のみに縮小
（gemspec の依存は `omniauth-oauth2` だけ、strategy 本体221行に `Rails.` / `secrets` /
`Decidim` の参照ゼロ。GitHub API で実物を確認済み）。

なお v1.4.0 の engine には **Decidim 0.28 以降で警告を出す**コードがあり、
cfj は 0.30 でそれを踏んだまま運用していた。

#### 対応方針

`Decidim.config.omniauth_providers` への追加（`line_login` と同じ形、main の
secrets.yml にあった12キーを `Decidim::Env` で組み立て）でアプリ側で塞げるが、
**今は実施しない**。gem 側の更新を待つ方針。

- `client_id` / `client_secret` は `OMNIAUTH_CITYOS_DCP_*` と
  `OMNIAUTH_CITYOS_DCP_LOGIN_*` の2系統フォールバックが必要
- 資格情報自体は組織ごとの `omniauth_settings`（暗号化）から読む。
  `enabled` だけは素の `true` で保存される（`tenant_enabled_providers` が
  `value == true` を見るため）

#### 切替前に確認すること

CDK には CityOS 関連の環境変数が**一切無い**。資格情報は組織ごとの DB 設定にあるため、
本番で実際に使われているかは DB でしか判定できない。

```sql
SELECT id, host FROM decidim_organizations
WHERE omniauth_settings ? 'omniauth_settings_cityos_dcp_login_enabled';
```

**0件なら 0.31 切替のブロッカーにならない。1件以上あればそのテナントで
CityOS ログインが使えなくなる。**

---

## 未確認（着手時に潰す）

1. **本番/ステージング DB の実データを見ていない** — 付録Bの事前確認 SQL で確定させる
2. **rake が既に本番で実行済みかはリポジトリからは判定不能**。ECS exec の作業ログ側の確認が必要
3. **`db/data_schema.rb` の version がローカル DB 由来か本番由来か不明**。本番の `data_migrations` テーブルを直接確認すべき
4. **fork gem 5本の Rails 7.2 defaults 適合性は未検証** — 特に `serialize`、外部 `redirect_to`、
   `raise_on_assign_to_attr_readonly`
5. **CDK の `REDIS_CACHE_EXPIRES_IN` 実値** — 0/負値/非数値だと 7.1 の
   `raise_on_invalid_cache_expiration_time` で例外化
6. `load_defaults 7.2` にして `bundle exec rspec` を実際に回した結果（本監査は静的突合のみ）
7. `config/cable.yml` と ActionCable 設定を残している意図（既存判断か放置か）

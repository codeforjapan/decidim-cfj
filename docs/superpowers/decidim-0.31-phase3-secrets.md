# Phase 3: `Rails.application.secrets` 撤去 — 変更インベントリ

> Decidim 0.31 は Rails 7.2 化に伴い `Rails.application.secrets` を廃止。cfj の該当箇所を ENV 直参照へ移し、`config/secrets.yml` と（大半の）`config/initializers/decidim.rb` を撤去する。
> 一次情報: RELEASE_NOTES v0.31.1 §2.2 / core.rb#L242(`Decidim::Env` 直呼び）/ PR #13268。関連: [[project_decidim_031_upgrade_impact]] [[feedback_decidim_upgrade_workflow]]
>
> **セルフレビュー反映済み(R1〜R6)**: 削除より「inline 保持」を既定に一本化 / gem が肩代わりする secrets を §5 に追記 / omniauth は要精査に格上げ / enable_proposal_linking 削除を確定 / スコープ・CSP 誇張を是正。

## 0. 実際に `Rails.application.secrets` を使っているのは3ファイル
| ファイル | 件数 | 中身 |
|---|---|---|
| `config/initializers/decidim.rb` | 82 | decidim/maps/etherpad/admin_password/各モジュール設定 |
| `config/environments/production.rb` | 7 | SMTP 設定(smtp_address/port/auth/username/password/domain/starttls) |
| `config/initializers/omniauth_line.rb` | 1 | `Rails.application.secrets[:omniauth]` |

> `storage.yml` / `database.yml` は実際には `Rails.application.secrets` を使っていない（先の集計「1件」は `secret_key_base` 等の別語マッチ）。ただし storage.yml は 0.31 で `public: true` 化のため差し替え対象。

---

## 1. ファイル別の変更方針

### A. `config/secrets.yml` → 削除（`git rm`）
中身は「ENV → キー名」の中継。各セクションの行き先:

| secrets.yml セクション | 移行先 |
|---|---|
| `decidim_default`(`DECIDIM_*`) | **既定は decidim.rb に inline 保持**（secrets.yml の `Decidim::Env` 式をそのまま移植）。gem 0.31 も同じ ENV を読むため理屈上は削除可だが、**cfj 既定が gem 既定と一致し、かつ ENV 設定済みと確認できたキーだけ**削除。→ R1 参照 |
| `omniauth`(facebook/line_login/cityos) | **要精査**（ワンライナー扱い禁止）。omniauth_line.rb のロジック + DB の organization 別 `omniauth_settings` も絡む。→ §1.E / R2 |
| `maps` / `etherpad` | decidim.rb 内で `MAPS_*` / `ETHERPAD_*` を ENV 直参照(複合ブロックなので単純置換ではない) |
| `geocoder` / `vapid` / `elections` / `storage` | **cfj コードは直接読んでいない**。0.30 では gem 本体が secrets を読んでいた → 0.31 は gem が ENV 直読み。**cfj は ENV 設定を担保して secrets.yml を消すだけ**。→ §5 参照 |

### B. `config/initializers/decidim.rb` → スリム化（独自分だけ ENV 直参照で残す）
→ 下の「2. decidim.rb の分類」参照。

### C. `config/environments/production.rb` → 0.31版に差し替え + SMTP を ENV 直参照
7つの `Rails.application.secrets.smtp_*`(L81-87)を `ENV["SMTP_ADDRESS"]` 等へ。0.31 公式は production.rb 自体をリリース版に差し替え推奨 → リリース版を土台に cfj 独自分（SMTP/その他）をマージするのが安全。

### D. `config/storage.yml` → 0.31版（ENV + `public: true`）に差し替え
secrets 参照は無いが、0.31 の ActiveStorage `public: true`(アセット URL 形式変更）が必要。CSP 更新（Phase 6）と連動。cfj の S3 設定を 0.31 テンプレに移植。

### E. `config/initializers/omniauth_line.rb` → `secrets[:omniauth]` を ENV 直参照へ（⚠️要精査）
`Rails.application.secrets[:omniauth]`(L16)を、omniauth 設定を ENV から組み立てる形に。
**注意(R2)**: これは1行置換では終わらない。omniauth_line.rb の実ロジック未確認 + facebook/cityos プロバイダの設定経路(secrets.yml の `omniauth:` セクション + DB の organization 別 `omniauth_settings`）も絡む。**着手前に omniauth 周りを独立して調査**すること。

---

## 2. `decidim.rb` の中身の分類（肝）

> **スコープ注記(R5)**: 「82件」には**コメントアウト行**(maps の HERE 例 L47-52/69/92、`# config...` の L15/23/154/293 等)が多数含まれる。これらは移行不要で**ファイル整理で消えるだけ**。実際に手を動かすアクティブ行はもっと少ない。
> **ハードコード値の注記(R4)**: `smtp_starttls_auto: true` や admin_password の一部など、secrets.yml でも ENV でなく**リテラル**の項目がある。これらは「ENV 直参照」ではなく**リテラルのまま移す or 新 ENV 化**を個別判断する。

### 🟢 そのまま残す（secrets 不使用の cfj 独自設定）
L18 `available_locales=[:ja,:en]` / L155 `currency_unit="円"` / L294 `default_csv_col_sep=","` / L314 `enable_machine_translations=false` / L339 machine_translation_service / L396-404 `content_security_policies_extra` / L469-518(i18n・assets_path・`cfj_osm` マップ・blog OGP・Devise・GraphQL complexity・CSP frame/script-src・LINE アイコン/シェア・etiquette off)

### 🟡 ENV 直参照へ書き換え（secrets → `Decidim::Env`/`ENV`）
- 単純 DECIDIM_* 群(L5,8,24,29,38,43,158,162,164,165,168,183,186,189,192,195,198,206,343,385-394 ほか): `application_name` / `mailer_sender` / `default_locale`(cfj は `:ja`)/ `force_ssl` / `throttling_*` / `maximum_*` / `consent_cookie_name` / `enable_remember_me` など
  → secrets.yml に既にある `Decidim::Env.new("DECIDIM_X", 既定)` 式をそのまま decidim.rb に移す（挙動不変・低リスク）
- 複合ブロック:
  - maps(L111-145)→ `MAPS_*` ENV 直参照
  - etherpad(L284-290)→ `ETHERPAD_*`
  - admin_password(L376-382)→ `DECIDIM_ADMIN_PASSWORD_*`
  - api / proposals / meetings / budgets / accountability / initiatives(L407-467)→ 各 `DECIDIM_*` ENV

### 🔴 0.31 で削除された設定 → 行ごと撤去
- **`enable_proposal_linking`**(meetings L428-430 / budgets L436-438 / accountability L444-446)→ **✅0.31 で削除を確定**（v0.31.1 の meetings/budgets/accountability.rb に config_accessor が存在しない）。残すと **boot 時 NoMethodError** → 該当行を必ず削除。
- maps の HERE maps コメント群(L47-52 等)→ HERE 設定は 0.31 で撤去。cfj は OSM 主体なので実害は要確認（コメント行なのでファイル整理で消えるだけ）。

---

## 3. 推奨の進め方（安全第一）
1. **既定は「inline 保持で挙動不変」に一本化(R1)**: decidim.rb の 🟡 は secrets.yml の `Decidim::Env` 式をそのまま移植する。**"gem 既定に任せて削除" は最適化であって既定ではない** — キー単位で「cfj 既定 == gem 既定 かつ ENV 設定済み」を確認できたものだけ削る（例: `mailer_sender` は cfj `info@diycities.jp` vs gem `change-me@example.org` と相違 → 削除不可、保持必須）。
2. production.rb は 0.31 リリース版を土台に SMTP 等 cfj 分をマージ。
3. omniauth_line.rb の `secrets[:omniauth]` を ENV 組み立てへ。
4. storage.yml を 0.31 版（public:true）へ。
5. `secrets.yml` 削除。
6. `bin/rails runner 'puts Decidim.version'` が通るまで（コンテナ内で）反復。🔴 の削除設定は起動エラーで炙り出せる。

---

## 4. 注意点（cfj 固有）
- cfj 独自デフォルトの棚卸しが肝: `default_locale :ja` / `application_name "Code for Japan Decidim"` / `mailer_sender "info@diycities.jp"` / `available_locales` リスト / `currency_unit "円"` などは gem 標準と違うので必ず保持（本番は SSM の ENV があるので実際は ENV 優先だが、dev/local の既定として残す）。
- `content_security_policies_extra`(R6): cfj の現状 CSP は**すべて `"*"`**(L396-404)なので S3 public URL も既に許可済み → 0.31 の public 化に伴う **CSP 追記は実質不要**。将来ワイルドカードを締める話は別タスク。

---

## 5. gem が肩代わりする secrets（0.30→0.31 の要点、R3）
`Rails.application.secrets` を実際に使う cfj コードは3ファイルのみ。では secrets.yml の `geocoder:` / `vapid:` / `elections:` / `storage:` は 0.30 で誰が読んでいたか? → **decidim gem 本体**が読んでいた（PR #13268 が ENV 化した対象そのもの）。

- **0.31 では gem が ENV を直読み**するので、これらは **cfj 側で移植コードを書く必要がない**。
- cfj がやること = **対応する ENV 変数が全環境で設定されていることを確認 → secrets.yml を削除するだけ**。
- ただし storage は 0.31 で `public: true` 追加のため storage.yml 差し替えは別途必要（§1.D)。
- 逆に **maps / etherpad は cfj の decidim.rb が明示的に組み立てている**（gem 任せでない）ので、こちらは inline 移植が要る（§2 複合ブロック）。

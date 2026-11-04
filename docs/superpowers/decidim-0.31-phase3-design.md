# Phase 3 実装設計書 — `Rails.application.secrets` 撤去(改訂版・挙動検証済み)

> 前提: [[decidim-0.31-phase3-secrets]](インベントリ)の実装設計。**セルフレビュー + 挙動徹底検証を反映した確定版**。
>
> ## 戦略の要点(旧版からの転換)
> - **旧案「secrets.yml の式を decidim.rb に inline」は誤り**。`Decidim::Env#to_boolean_string` は文字列 `"true"/"false"` を返し、旧 secrets.yml は**それを YAML が boolean へ再パース**していた。Ruby に直接 inline すると型変換が失われ、`"false".present?`=true 等で **boolean 系が壊れる**。
> - **正しい戦略 =「pass-through 行は削除して 0.31 gem の config_accessor 既定に委譲」**。gem は同じ `DECIDIM_*` ENV を**正しい型処理で**読む。cfj は「gem 既定と異なるキー」だけ明示保持する。
>
> ## 検証済みの根拠
> - cfj が設定する config accessor は **`enable_proposal_linking` を除き 0.31 に全存続**(core/各モジュールで grep 確認)。
> - **ENV 変数名は全キー一致**(DECIDIM_/API_/PROPOSALS_/MEETINGS_/INITIATIVES_)。差が出るのは「既定値の相違 × ENV 未設定時」のみ。
> - **CDK(decidim-stack.ts)が一部 ENV を設定済み**(admin_password 4種/enable_html_header_snippets/SMTP/cache)。これらは本番で gem がその値を読むため削除安全。
> - `Rails.application.secrets` 実消費は decidim.rb(82)/ production.rb(7 SMTP)/ omniauth_line.rb(1) の3ファイル。

---

## ファイル①: `config/initializers/decidim.rb`

### 方針
`Decidim.configure`/各 `Decidim::X.configure` ブロックは維持。中の secrets 参照行を下記分類で処理。🟢は**行ごと削除**、🟡は**明示保持(cfj 既定つき Decidim::Env or ハードコード)**、🔴は**削除必須**。

### 🔴 削除必須(残すとバグ)
| 行 | 理由 |
|---|---|
| L164 `maximum_attachment_size = ...to_i.megabytes` | 0.31 は生MB規約(`organization_settings` が `Decidim.maximum_attachment_size.to_f` を MB として使用)。`.megabytes`(=10485760)を残すと桁破綻。**削除→gem 既定 10MB = 現状維持**。※`.megabytes` は decidim 0.29/0.30 雛形由来で、0.31 で decidim 自身が撤去した |
| L165 `maximum_avatar_size = ...to_i.megabytes` | 同上 |

### 🟢 削除して挙動不変(ENV名・既定値・型処理まで一致 / または CDK が肩代わり)
force_ssl(※production.rb:43 が `config.force_ssl=true` 直設定=本番常に true)/ cors_enabled / service_worker_enabled / enable_html_header_snippets(**CDK=true**)/ image_uploader_quality / max_reports_before_hiding / track_newsletter_links / download_your_data_expiry_time / throttling_max_requests / throttling_period / unconfirmed_access_for / system_accesslist_ips / base_uploads_path / consent_cookie_name / cache_key_separator / expire_session_after / enable_remember_me / session_timeout_interval / follow_http_x_forwarded_host / maximum_conversation_message_length / denied_passwords / allow_open_redirects
- **admin_password 4種(L376-382)**: gem 既定(true/90/15/5)と違うが **CDK が `false/0/8/1000` を設定済み** → 削除で **CDK 値が効き現状維持**。ブロックごと削除可
- **api ブロック(L407-413)**: `API_SCHEMA_MAX_PER_PAGE=50 / _COMPLEXITY=5000 / _DEPTH=15` 完全一致 → ブロック削除可
- **proposals ブロック(L415-420)**: `PROPOSALS_..._LIMIT=4/3` 一致 → ブロック削除可

### 🟡 明示保持(cfj 既定 ≠ gem 既定)
| キー | cfj | gem 0.31 既定 | 保持方法 |
|---|---|---|---|
| available_locales(L18) | `[:ja,:en]` | 巨大リスト | **ハードコード維持** |
| currency_unit(L155) | `"円"` | `"€"` | **ハードコード維持** |
| default_csv_col_sep(L294) | `","` | `";"` | **ハードコード維持** |
| default_locale(L24) | `"ja"` | `"en"` | `config.default_locale = Decidim::Env.new("DECIDIM_DEFAULT_LOCALE", "ja").to_s.presence \|\| :ja`(CDK 未設定でも dev で ja) |
| application_name(L5) | "Code for Japan Decidim" | "My Application Name" | `= Decidim::Env.new("DECIDIM_APPLICATION_NAME", "Code for Japan Decidim").to_s` |
| mailer_sender(L8) | "info@diycities.jp" | "change-me@example.org" | `= Decidim::Env.new("DECIDIM_MAILER_SENDER", "info@diycities.jp").to_s` |

> 🟡 の3 ENV キーは「cfj 既定つき Decidim::Env」で保持すれば dev/本番とも安全。CDK 追加は任意(§CDK 参照)。

### 🟠 モジュール軽微差(実運用次第・要判断)
| 行 | cfj 既定 | gem 0.31 既定 | 判断 |
|---|---|---|---|
| initiatives `default_components`(L457) | "pages, meetings" | "pages, meetings, **blogs**" | blogs 追加を許容するか。許容なら**ブロック削除**、維持なら明示保持 |
| meetings `embeddable_services`(L426) | secrets 既定**空** | "youtube twitch jitsi" | 空運用を維持するか。gem 既定許可でよければ削除 |
| initiatives `creation_enabled`/`print_enabled`(L452/462) | `unless=="auto"` | `"auto".present?`=true / `=="true"`=false | "auto" 解釈差。基本は削除で問題ないはず(要スモーク) |
| initiatives その他(L455-465) | 一致 | 一致 | 削除可 |
| meetings `upcoming_meeting_notification`(L424) | 2d 一致 | 2d 一致 | 削除可 |

### 🔴 削除(0.31 で config accessor 削除済み)
- meetings `enable_proposal_linking`(L428-430)/ budgets ブロック(L434-440 全体)/ accountability ブロック(L442-448 全体)→ **残すと boot 時 NoMethodError**。budgets/accountability は中身が enable_proposal_linking のみ = **`if Decidim.module_installed?` ごと削除**

### 🟢 無変更(secrets 非依存の cfj 独自)
L229/254/277 各 service / L314 machine_translations false / L339 translator / L396-404 CSP extra / L469-518(i18n/assets/cfj_osm/blog OGP/Devise/GraphQL/CSP frame・script/LINE/social_share/etiquette/content_blocks)

### maps ブロック(L111-145)/ etherpad(L284-290)
gem 委譲ではなく **cfj が明示組み立て** → **保持**。`Rails.application.secrets.maps[:X]` を `Decidim::Env.new("MAPS_X", 既定)` へ置換(secrets.yml L152-163 が対応表)、gate は `if Decidim::Env.new("MAPS_STATIC_PROVIDER", ENV["MAPS_PROVIDER"]).to_s.present?`。etherpad も同様(`ETHERPAD_*`)。

---

## ファイル②: `config/environments/production.rb`(L80-89 SMTP)
```ruby
config.action_mailer.smtp_settings = {
  address: ENV["SMTP_ADDRESS"],
  port: Decidim::Env.new("SMTP_PORT", 587).to_i,
  authentication: Decidim::Env.new("SMTP_AUTHENTICATION", "plain").to_s,
  user_name: ENV["SMTP_USERNAME"],
  password: ENV["SMTP_PASSWORD"],
  domain: ENV["SMTP_DOMAIN"],
  enable_starttls_auto: Decidim::Env.new("SMTP_STARTTLS_AUTO", "true").value != "false",  # ★下記注記
  openssl_verify_mode: "none"
}
```
> ★ **starttls 是正(要判断)**: CDK は `SMTP_STARTTLS_AUTO`('false' dev/staging, 'true' prod)を設定しているのに、現行 cfj は secrets.yml の固定 `true` で**無視**している。上記のように ENV 尊重に直すと dev/staging(ローカルダミー SMTP:1025)の starttls off が正しく効く。**挙動を変える修正**なので、staging 等でメール送信に問題が出ているか確認して採否を決める。挙動不変を優先するなら `enable_starttls_auto: true` 固定のままでも可。

---

## ファイル③: `config/initializers/omniauth_line.rb` + line_login 登録
### 変更1: プロバイダ取得を 0.31 方式へ(1行)
```ruby
-  omniauth_config = Rails.application.secrets[:omniauth]
+  omniauth_config = Decidim.omniauth_providers
```
### 変更2: line_login を `Decidim.omniauth_providers` に登録(decidim.rb に追記)
0.31 の `Decidim.omniauth_providers` は facebook/twitter/google/developer のみ。line_login を追加:
```ruby
Decidim.config.omniauth_providers = Decidim.omniauth_providers.merge(
  line_login: {
    enabled: Decidim::Env.new("OMNIAUTH_LINE_LOGIN_CHANNEL_ID").present?,
    client_id: Decidim::Env.new("OMNIAUTH_LINE_LOGIN_CHANNEL_ID", nil),
    client_secret: Decidim::Env.new("OMNIAUTH_LINE_LOGIN_CHANNEL_SECRET", nil)
    # icon_path は不要: ボタンは oauth_icon(provider) が Decidim.icons.register("line") から描画する
  }
)
```
> `setup_provider_proc`(org 別 creds 注入)は 0.31 gem と同一で無変更。dev の developer ログインは gem 既定が `Rails.env.local?` で有効化するため secrets の dev セクション相当は不要。config_accessor の setter 挙動(`Decidim.config.omniauth_providers=`)は実装時に boot 確認。

---

## ファイル④: `config/storage.yml`
現状すでに ENV ベース。**`amazon:` に `public: true` 追加**(0.31 ActiveStorage キャッシュ対策):
```yaml
amazon:
  service: S3
  region: ap-northeast-1
  bucket: <%= ENV.fetch("AWS_BUCKET_NAME", "cfj-decidim") %>
  public: true
```
> CSP は cfj 現状 `"*"` のため追記不要。

---

## ファイル⑤: `config/secrets.yml` → 削除(`git rm`)
上記移行後に削除。gem が ENV 直読みで肩代わりするセクション(geocoder/vapid/storage/elections)は cfj コード非参照 → 対応 ENV 設定済みなら削除のみ。**要判断**: elections/vapid を実運用しているか。
- **secret_key_base**: dev/test はリテラル、production は `ENV["SECRET_KEY_BASE"]`(Dockerfile は `SECRET_KEY_BASE=placeholder` 設定済/本番 SSM)。secrets.yml 削除で dev/test の secret_key_base 移行先を決める(credentials / ENV / `tmp/local_secret.txt`)。

---

## CDK 側の対応(decidim-cfj-cdk / decidim-stack.ts)
### 既設(=削除安全の裏付け)
`DECIDIM_ADMIN_PASSWORD_{STRONG=false,EXPIRATION_DAYS=0,REPETITION_TIMES=1000,MIN_LENGTH=8}` / `DECIDIM_ENABLE_HTML_HEADER_SNIPPETS=true` / `SMTP_*` / `DECIDIM_CACHE_EXPIRATION_TIME=60` / `DECIDIM_COMMENTS_LIMIT=30`

### 追加提案(任意・本番設定を CDK で明示化したい場合)
`DecidimContainerEnvironment` に追記。※decidim.rb 側で cfj 既定つき Decidim::Env で保持していれば**必須ではない**(dev フォールバックのため decidim.rb 保持は推奨)。
```ts
DECIDIM_APPLICATION_NAME: 'Code for Japan Decidim',
DECIDIM_MAILER_SENDER: 'info@diycities.jp',
DECIDIM_DEFAULT_LOCALE: 'ja',
```
- `DECIDIM_MAXIMUM_ATTACHMENT_SIZE` は追加不要(削除で gem 既定 10MB=現状維持。変えたい場合のみ追加)
- available_locales/currency_unit/csv は decidim.rb ハードコード維持のため CDK 不要

---

## 実行順序
1. decidim.rb: 🔴削除(attachment/avatar/enable_proposal_linking)+ 🟢削除(pass-through/admin_password/api/proposals)+ 🟡明示保持化 + maps/etherpad の ENV 置換
2. line_login 登録追記(decidim.rb)
3. omniauth_line.rb の1行置換
4. production.rb SMTP 置換(starttls の採否を決める)
5. storage.yml に public:true
6. secret_key_base の dev/test 移行先決定
7. `secrets.yml` 削除
8. (任意)CDK に application_name 等追加
9. コンテナ内 `bin/rails runner 'puts Decidim.version'` → boot 確認、反復

## 検証チェックリスト
- [ ] `grep -rn "Rails.application.secrets" app config lib` = 0件
- [ ] `bin/rails runner 'puts Decidim.version'` 成功 / `zeitwerk:check` パス
- [ ] `bin/rails runner 'p [Decidim.application_name, Decidim.default_locale, Decidim.available_locales, Decidim.currency_unit, Decidim.maximum_attachment_size, Decidim.omniauth_providers.keys]'`
  期待: "Code for Japan Decidim" / :ja / [:ja,:en] / "円" / **10**(MB, ≠10485760)/ line_login 含む
- [ ] admin_password: `p [Decidim.admin_password_strong, Decidim.admin_password_min_length]` → 本番 ENV で false/8(CDK 値)
- [ ] メール送信(dev: letter_opener)で SMTP エラーなし
- [ ] 管理画面で LINE omniauth が選択肢に出る

## 要判断リスト → 調査で確定済み(2026-08-05)
1. **elections** … ✅**未使用確定**(`decidim-elections`/`votings`/`bulletin` は Gemfile.lock 0件、CDK も未設定)。secrets の elections/elections_default は死に設定 → **削除でOK、ENV/CDK 不要**
2. **vapid** … ✅**未使用確定**(VAPID_ キーが CDK/ENV に無し=web push 無効)。**削除で挙動不変**
3. **secret_key_base** … ✅**対応ほぼ不要**。本番は既存 `ENV["SECRET_KEY_BASE"]`(SSM/Dockerfile placeholder)。dev/test は secrets.yml 削除後に **Rails 7.2 が `tmp/local_secret.txt` を自動生成**。※dev のセッション維持したい場合のみ任意で `.env` に固定 `SECRET_KEY_BASE`
4. **line_login icon_path** … ✅**含めない**。ボタンは `oauth_icon(provider)` が provider 名→`Decidim.icons.register("line")` から描画し **icon_path は非消費**。line_login 登録は enabled/client_id/client_secret のみ(§ファイル③の `icon_path:` 行は削除)
5. **starttls** … ⚠️**是正推奨(既存バグ)**。全ステージ RAILS_ENV=production(Dockerfile 既定、CDK override 無し)= 全部 production.rb。CDK は dev/staging で `SMTP_PORT=1025`(ダミー)+`SMTP_STARTTLS_AUTO=false` なのに cfj は starttls=true 固定 → dev/staging のメール送信が失敗しうる。§ファイル② のとおり **ENV 尊重に是正**(prod=true 維持、dev/staging が off に)
6. **CDK 追加**(application_name/mailer_sender/default_locale) … ✅**見送り**。decidim.rb に `Decidim::Env`(cfj 既定つき)で保持すれば dev/本番とも安全=**CDK 追加不要**(§ファイル①🟡)
7. **🟠 モジュール差**(initiatives default_components +blogs / meetings embeddable_services 既定リスト) … **gem 既定を受け入れてブロック削除を推奨**(より寛容/標準的になるだけで実害小)。念のため実地スモークで確認

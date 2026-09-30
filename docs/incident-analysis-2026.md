# CPU 高負荷障害 調査レポート

**調査日**: 2026-05-26  
**調査対象**: prd-v0292 本番環境 ECS サービス (`prd-v0292DecidimCluster/prd-v0292DecidimService`)  
**ログソース**: ALB アクセスログ（S3: `prd-v0292-decidim-alb-logs`）、CloudWatch ECS メトリクス

---

## 1. CPU スパイック発生状況（2026年2月〜5月）

CloudWatch ECS メトリクス（1時間粒度、Maximum）から CPU 60% 超を記録した日時の一覧。

| 日時（JST） | CPU最大値 | ALBログ |
|---|---|---|
| 2026-02-05 08:00 | 95.96% | 調査済み |
| 2026-02-13 13:00 | 68.59% | 調査済み |
| 2026-02-26 13:00 | 63.28% | 調査済み |
| 2026-02-27 13:00 | 98.68% | 調査済み |
| 2026-03-18 03:00 / 23:00 | 99.94% / 100.16% | 調査済み |
| 2026-03-23 13:00 | 72.50% | 調査済み |
| 2026-03-24 15:00 / 19:00 | 94.42% / 78.18% | 調査済み |
| 2026-03-25 12:00 | 70.98% | 調査済み |
| 2026-03-26 02:00 / 03:00 | 97.03% / 70.88% | 調査済み |
| 2026-03-27〜29 | 82〜100%（複数時間帯） | 調査済み |
| 2026-03-30 12:00 | 96.71% | 調査済み |
| 2026-04-02 03:00〜11:00 | 62〜97% | 調査済み |
| 2026-04-03 03:00 / 07:00〜11:00 | 100%（複数回） | 調査済み |
| 2026-04-08〜09 10:00 / 19:00 | 96〜99% | 調査済み |
| 2026-04-18 03:00 | 81% | 調査済み |
| 2026-04-28 10:00 | 93% | 調査済み |
| 2026-04-30 19:00 | 99.89% | 調査済み |
| 2026-05-01 11:00 | 100.01% | 調査済み |
| 2026-05-06 22:00 | 100.05% | 調査済み |
| 2026-05-13 03:00 | 90.06% | 調査済み |
| 2026-05-14 19:00 | 100.07% | 調査済み |
| 2026-05-17 18:00 | 99.98% | 調査済み |
| 2026-05-22 11:00〜12:00 | 100.05% / 96.40% | 調査済み |

**特記**: 3月下旬（3/23〜3/30）は 8 日間にわたり断続的に 60〜100% の高負荷が継続しており、最も深刻な期間。

---

## 2. 各障害日の詳細（ALBログ分析）

### 2026-02-05（CPU 95.96%）

- **ピーク時間**: 12:35〜12:40 JST（1,034〜885 req/5min）
- **集中ドメイン**: `shinagawa.makeour.city`（スパイック時 1,816件、通常比 **9.6倍**）
- **User-Agent**: `Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36` が 1,793件（スパイック時の97%）
  - `(Linux; Android 10; K)` は Android Webview 系アプリで見られる省略形式
- **集中パス**: `/profiles/*/tooltip`（1,663件）— コメント一覧上の全ユーザーアバター tooltip が連鎖読み込みされた
- **アクセス元 IP**: `3.172.107.x` シリーズ（CloudFront 経由）

### 2026-02-13（CPU 68.59%）

- **ピーク時間**: 14:05〜14:30 JST（820〜728 req/5min）
- **ドメイン分散**: `inochi-forum.makeour.city` 13%、`shinagawa` 11%、`dev-v-0-27-4-kakogawa` 10%
- **User-Agent**: `Windows Chrome` 35%、UA `-`（不明）10%
- **遅いパス**: `dev-v-0-27-4-kakogawa.diycities.jp/system`（201件）、`hyogo-vision.diycities.jp/system`（165件）
- **特記**: `/system/` への遅いアクセスが 2 ドメインで 400件近く発生。EC2ドメイン直打きも 91件

### 2026-02-26（CPU 63.28%）

- **ピーク時間**: 13:30〜13:45 JST（1,676〜1,785 req/5min）
- **集中ドメイン**: `shinagawa.makeour.city` **62%**（9,095件）、`inochi-forum.makeour.city` 21%（3,199件）
- **User-Agent**: `Windows NT 10.0 Chrome` が **74%**（10,852件）に集中
- **遅いパス**: EC2ドメイン直打き `/system/`（56件）

### 2026-02-27（CPU 98.68%）

#### 原因 1：管理画面への集中アクセス（スキャン攻撃疑い）
- **IP**: `20.100.197.204`（Microsoft Azure のIPレンジ）→ 910件、**通常比 364倍**
- **アクセス先**: `ec2-52-69-25-101.ap-northeast-1.compute.amazonaws.com/system/`（ALB の EC2 ドメイン直打ち）
- **User-Agent**: `-`（不明）
- `/system/admins/sign_in` への試行も 230件

#### 原因 2：inochi-forum コメントページネーション
- `inochi-forum.makeour.city/comments?...after=XXXXX` への連続アクセス
- 同一提案のコメントを大量ページネーション

### 2026-03-18（CPU 99.94% / 100.16%）

- **ピーク時間**: 02:25 JST（深夜）— 通常想定外の時間帯
- **集中ドメイン**: `youth-setagaya-test.makeour.city`（56%）
- **User-Agent**: `Mac OS X 10_15_7 Chrome`（57%）
- **遅いパス**: `kokubunjivision.diycities.jp/system`（54件）
- **特記**: 深夜帯のスパイックは人手によるアクセスとは考えにくい

### 2026-03-23（CPU 72.50%）

- **ピーク時間**: 11:55〜13:45 JST
- **ドメイン分散**: `kakogawa` 26%、`inochi-forum.makeour.city` 13%、`shinagawa` 11%、`aict` 9%
- **遅いパス**: `meta.diycities.jp/`（56件）、`aict.makeour.city/assemblies`（14件）
- 複数サイトへの分散で単一原因なし

### 2026-03-24（CPU 94.42% / 78.18%）

- **ピーク時間**: 19:05 JST に **2,963 req/5min**（突出）
- **集中ドメイン**: `52.69.180.16`（ALB の IP 直打ち）**42%**（2,897件）
- **User-Agent**: `Windows Chrome` 57%、UA `-` 15%、`Android 10; K` 6%
- **遅いパス**: EC2ドメイン直打き `/system/`（150件）、`inochi-forum.makeour.city/assemblies`（65件）
- **特記**: ALB の IP アドレス直打ちによるアクセスが 42% を占めるのは異常。スキャン攻撃の可能性

### 2026-03-25（CPU 70.98%）

- **ピーク時間**: 11:30〜11:50 JST（413〜461 req/5min）
- **ドメイン分散**: `shinagawa` 29%、`aict` 22%、`kakogawa` 15%
- **遅いパス**: `meta.diycities.jp/`（54件）、`meta.diycities.jp/assemblies`（12件）
- 複数サイトへの分散

### 2026-03-26（CPU 97.03% / 70.88%）

- **ピーク時間**: 00:55〜02:35 JST（深夜〜未明）に 510〜538 req/5min
- **集中ドメイン**: `inochi-forum.makeour.city` **62%**（11,270件）、`kakogawatest` 18%（3,262件）
- **User-Agent**: `Windows NT 10.0 Chrome` が **86%**（15,547件）に集中
- **遅いパス**: `meta.diycities.jp/`（72件）、`kakogawa.diycities.jp/processes`（39件）
- **特記**: 深夜帯に `inochi-forum` へのアクセスが集中。UA が 86% 一種に偏る

### 2026-03-27〜03-29（CPU 90〜100%、3日間継続）

3月下旬における最大規模の障害期間。

| 日 | 主要ドメイン占有率 | ピーク時リクエスト数 |
|---|---|---|
| 3/27 | `inochi-forum.makeour.city` 79%（10,531件） | 265 req/5min |
| 3/28 | `inochi-forum.makeour.city` 75%（8,656件） | 335 req/5min |
| 3/29 | `inochi-forum.makeour.city` 80%（12,003件） | 435 req/5min |

- **User-Agent**: `Windows NT 10.0 Chrome` が 63〜82% に集中
- **遅いパス**: `meta.diycities.jp/assemblies`（3/28 に 328件）
- **アクセス元 IP**: `15.158.241.x`、`3.172.107.x`（CloudFront 経由）
- 単一UAへの集中度が高いが、リクエスト数・多様なIPから実ユーザーによる一斉アクセスの可能性もある

### 2026-03-30（CPU 96.71%）

- **ピーク時間**: 12:15〜13:35 JST（496〜506 req/5min）
- **集中ドメイン**: `inochi-forum.makeour.city` **69%**（6,251件）
- **User-Agent**: `Windows NT 10.0 Chrome` が **85%**（7,680件）
- **遅いパス**: `meta.diycities.jp/assemblies`（23件）
- 3/27〜3/29 から継続する `inochi-forum` 集中の延長

### 2026-04-01〜04-02（CPU 62〜97%）

#### 2026-04-01
- **ピーク時間**: 02:15〜03:40 JST（深夜）
- **User-Agent**: **`meta-externalagent/1.1`（Facebook OGPクローラー）23%**（378件）
- **遅いパス**: `inochi-forum.org/assemblies`（15件）、`/processes`（10件）

#### 2026-04-02
- **ピーク時間**: 07:00〜08:50 JST（245〜344 req/5min）
- **集中ドメイン**: `meta.diycities.jp` 34%（793件）
- **User-Agent**: **`meta-externalagent/1.1` 34%**（782件）— 全体の3分の1
- **遅いパス**: `meta.diycities.jp/assemblies`（**477件が2秒超**）— 非常に高負荷

### 2026-04-03（CPU 100% ×3回）

- **主要ドメイン**: `inochi-forum.org` 31%、複数ドメインに分散
- **遅いパス**: `/system`（`hamamatsu.makeour.city` 54件、`itoman2025.diycities.jp` 20件）
- 4/1〜4/2 の Facebookクローラー起因の高負荷が継続した可能性

### 2026-04-08（CPU 99.98%）

- **ピーク時間**: 10:30 JST（701 req/5min）
- **主要ドメイン**: `aict.makeour.city` 40%（3,183件）、`inochi-forum.org` 33%（2,640件）
- **User-Agent**:
  - `Mac Chrome` 42%、`Windows Chrome` 30%
  - **`meta-externalagent/1.1` 463件（5%）**
  - UA `-`（不明）590件（7%）
- **遅いパス**: `inochi-forum.org/assemblies`（189件）
- EC2ドメイン直打ち `/system/`（589件）

### 2026-04-09（CPU 96.71%）

- **ピーク時間**: 18:05〜19:40 JST（314〜348 req/5min）
- **主要ドメイン**: `inochi-forum.org` 25%（1,002件）、`youth-setagaya-test` 22%（910件）
- **User-Agent**:
  - UA `-`（不明）16%（664件）
  - **`meta-externalagent/1.1` 9%**（380件）
- **遅いパス**: `inochi-forum.org/assemblies`（172件）、EC2ドメイン直打き `/system/`（104件）

### 2026-04-18（CPU 81%）

- **ピーク時間**: 04:20〜04:25 JST（深夜）
- **主要ドメイン**: `kakogawa` 26%、`inochi-forum.org` 15%、`okinawa2024` 15%
- **遅いパス**: `okinawa2024.diycities.jp/system`（71件）、`inochi-forum.org/assemblies`（32件）

### 2026-04-28（CPU 93%）

- **ピーク時間**: 10:50〜11:10 JST（397〜605 req/5min）
- **主要ドメイン**: `shinagawa` 33%（1,176件）、`inochi-forum.org` 25%（918件）
- **遅いパス**: `inochi-forum.org/assemblies`（29件）

### 2026-04-30（CPU 99.89%）

- **ピーク時間**: 19:35 JST（349 req/5min）
- **主要ドメイン**: `inochi-forum.org` 29%（1,332件）、`kakogawa` 24%、`kakogawatest` 20%
- **遅いパス**: `inochi-forum.org/action-panel`（21件）、`/system` 関連

### 2026-05-01（CPU 100.01%）

- **ピーク時間**: 11:40 JST（332 req/5min）
- **主要ドメイン**: `inochi-forum.org` 38%（1,997件）、`aict` 17%、`shinagawa` 14%、`kakogawa` 14%

### 2026-05-06（CPU 100.05%）

- **ピーク時間**: 22:30 JST（**821 req/5min**）— 深夜の突出スパイック
- **集中ドメイン**: `kakogawa.diycities.jp` **55%**（2,007件）
- **User-Agent**: `Windows Firefox` 36%（1,303件）、`Windows Chrome` 25%（904件）
- **遅いパス**: `kakogawa.diycities.jp/processes`（**615件が2秒超**）、`/profiles`（225件）
- **特記**: `kakogawa` の `/processes`（参加型プロセス一覧）が 615件も2秒超となる非常に重いページ

### 2026-05-13（CPU 90.06%）

- **ピーク時間**: 02:00〜03:25 JST（深夜）
- **主要ドメイン**: `kakogawatest` 32%、`youth-setagaya-test` 27%、`kakogawa` 15%、`inochi-forum.org` 10%
- **User-Agent**: `Windows Chrome` 45%、`Mac Chrome` 39%
- **遅いパス**: `/system` 関連複数

### 2026-05-14（CPU 100.07%）

- **ピーク時間**: 19:45 JST（294 req/5min）
- **主要ドメイン**: `inochi-forum.org` 37%（1,355件）、`youth-setagaya` 18%

### 2026-05-17（CPU 99.98%）

- **ピーク時間**: 18:35 JST に **850 req/5min** の突出スパイック
- **集中ドメイン**: `kakogawa.diycities.jp` 49%（1,310件）
- **User-Agent**: `Linux x86_64 Chrome` 28%（757件）
- **遅いパス**: `inochi-forum.org/assemblies`（10件）、`hamamatsu.makeour.city/system`（10件）

### 2026-05-22（CPU 100.05%）

- **ピーク時間**: 11:45〜12:05 JST（1,000 req/5min 超が持続）
- **最多 User-Agent**: **`meta-externalagent/1.1`（Facebook OGPクローラー）2,009件**（スパイック時の66%）
- **集中ドメイン**: `inochi-forum.org`（スパイック時 1,960件）
- **集中パス**: `inochi-forum.org/assemblies`（1,866件）
- **遅いパス**: `inochi-forum.org/assemblies`（**947件が2秒超**）
- **アクセス元 IP**: `52.46.3.x`、`130.176.189.x`（Amazon CloudFront IP）

---

## 3. 横断的に確認されたパターン

### パターン A: Facebook OGPクローラー集中型

`meta-externalagent/1.1`（Facebook/Meta が SNS シェア時に OGP 情報を取得するクローラー）による集中アクセス。

| 日付 | 件数 | 主な集中先 | 2秒超件数 |
|---|---|---|---|
| 4/1 | 378件（23%） | `inochi-forum.org/assemblies` | 15件 |
| 4/2 | 782件（34%） | `meta.diycities.jp/assemblies` | **477件** |
| 4/8 | 463件（5%） | `inochi-forum.org/assemblies` | 189件 |
| 4/9 | 380件（9%） | `inochi-forum.org/assemblies` | 172件 |
| 5/22 | **2,009件（66%）** | `inochi-forum.org/assemblies` | **947件** |

- `/assemblies`（集会一覧）と `/processes`（参加型プロセス一覧）が特に重い
- CloudFront の CachingDisabled 設定により全リクエストが Rails まで到達
- SNS でのリンクシェアが増えると連動してアクセスが急増する構造

### パターン B: 特定サイトへの大量アクセス型

単一ドメインへのアクセスが通常の数倍〜数十倍に集中する現象。イベント開催や告知との相関が疑われる。

| 期間 | 集中ドメイン | 占有率 | 特徴 |
|---|---|---|---|
| 2/5 | `shinagawa.makeour.city` | スパイック時 97% | `Android 10; K` UA が集中 |
| 2/26 | `shinagawa.makeour.city` | 62% | `Windows Chrome` 74% 集中 |
| 3/26 | `inochi-forum.makeour.city` | 62% | 深夜帯。`Windows Chrome` 86% |
| 3/27〜3/30 | `inochi-forum.makeour.city` | 69〜80% | 4日間継続 |
| 5/6 | `kakogawa.diycities.jp` | 55% | `/processes` が 615件遅延 |
| 5/17 | `kakogawa.diycities.jp` | 49% | 18:35 に突出 |

### パターン C: 管理画面スキャン攻撃

EC2 ドメイン直打きまたは ALB IP 直打ちで `/system/` に繰り返しアクセス。

| 日付 | アクセス先 | 件数 | IP / UA |
|---|---|---|---|
| 2/13 | EC2ドメイン直打き `/system/` | 291件（遅延） | — |
| 2/27 | EC2ドメイン直打き `/system/admins/sign_in` | 910件 | Azure IP `20.100.197.204`、UA `-` |
| 3/24 | ALB IP 直打き `52.69.180.16/system` | 2,897件（42%） | UA `-` 15% |
| 4/8 | EC2ドメイン直打き `/system/` | 589件 | — |
| 4/9 | EC2ドメイン直打き `/system/` | 104件 | UA `-` 16% |

全期間を通じて継続的に発生しており、自動化ツールによるスキャンと判断できる。

### パターン D: 深夜・特定時刻の突発スパイック型

| 日付 | ピーク時刻 | 集中先 | 備考 |
|---|---|---|---|
| 3/18 | 02:25 JST（深夜） | `youth-setagaya-test` | Mac Chrome 57% |
| 3/24 | 19:05 JST | ALB IP 直打き | 2,963 req/5min |
| 3/26 | 00:55〜02:35 JST（深夜〜未明） | `inochi-forum.makeour.city` | Windows Chrome 86% |
| 5/6 | 22:30 JST | `kakogawa` | `/processes` 615件遅延 |

### ボット・クローラーの継続的な存在

全期間を通じて以下が確認されている。

| 種別 | 件数/日（概算） | 備考 |
|---|---|---|
| UA `-`（不明） | 350〜930件 | 自動化ツール、スキャナー |
| `meta-externalagent/1.1` | イベント時に急増（最大 2,009件） | Facebook OGPクローラー（正規だが高負荷） |
| `libredtail-http` | 45〜107件 | OSSのHTTPクライアント、スクレイピング用途 |
| `Wget` | 23〜35件 | スクリプトアクセス |
| `DotBot` | 18〜29件 | Moz SEOクローラー |
| `UptimeRobot` | 140〜236件 | 死活監視（正規） |

---

## 4. 調査範囲の限界

- ALBログはスパイック前後 1〜2時間分のみ取得しており、1日全体のトレンドは未分析
- CPU スパイックと特定リクエストの直接因果関係は ALBログのみでは証明できない（New Relic 等との組み合わせが必要）
- CloudFront のキャッシュヒット率は本調査では取得していない
- UA の偽装可能性があるため、`Windows Chrome` が多い日の実際のクライアント種別は確定できない

---

## 5. 対策の優先度（ログ分析から導かれる事実ベース）

| 優先度 | 対象 | 根拠 |
|---|---|---|
| 高 | `/assemblies` および `/processes` の未ログインユーザー向けキャッシュ設定 | Facebookクローラーが 4/1〜4/2、4/8〜4/9、5/22 に繰り返し集中。最大 477〜947件が2秒超 |
| 高 | `/system/` への外部直接アクセスのブロック（WAF または セキュリティグループ） | 2/13、2/27、3/24、4/8、4/9 で継続確認。EC2ドメイン・ALB IP 直打きによる管理画面スキャンが常態化 |
| 中 | `inochi-forum.org` / `kakogawa` / `shinagawa` の大量アクセス時のスケールアップ速度改善 | 3/26〜3/30 の 5日間継続、5/6・5/17 の突発スパイックで追いつけていない可能性 |
| 中 | `kakogawa.diycities.jp/processes` の表示パフォーマンス改善 | 5/6 に 615件が2秒超。`/assemblies` と並ぶ重いページ |
| 低 | `libredtail-http` 等ボット系 UA の WAF ブロック | 継続的に存在するが、直接 CPU 100% の主因ではない |

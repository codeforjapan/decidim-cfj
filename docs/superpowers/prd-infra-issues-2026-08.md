# 本番インフラの課題（prd-v030 実測調査）

調査日: 2026-08-25 / 対象: `prd-v030` スタック（decidim 0.30.9、イメージ `decidim-cfj:prd-v030-v1.19.1`）
関連: `decidim-0.31-remaining-work.md` / `decidim-0.32-upgrade-plan.md`

decidim 0.31/0.32 アップグレードの過程で `load_defaults 7.2` の YJIT 有効化リスクを評価するため
本番の実メモリを測ったところ、**アップグレードとは無関係に既に発生している問題**が複数見つかった。
本ドキュメントはそれらを独立した課題として整理する。

---

## 調査に使ったコマンド（再現用）

```bash
export AWS_PROFILE=decidim AWS_REGION=ap-northeast-1

# Puma 合計メモリの分布（PWK が 60 秒ごとに出力している）
aws logs start-query --log-group-name prd-v030-decidim-serviceLogGroup \
  --start-time $(( $(date +%s) - 7*86400 )) --end-time $(date +%s) \
  --query-string 'filter @message like /PumaWorkerKiller: Consuming/
| parse @message "Consuming * mb" as mem
| stats count() as samples, min(mem), pct(mem,50), pct(mem,90), pct(mem,95), pct(mem,99), max(mem)'

# OOM reap の発生と犠牲 worker
aws logs start-query --log-group-name prd-v030-decidim-serviceLogGroup ... \
  --query-string 'filter @message like /Out of memory/
| parse @message "Sending TERM to pid * consuming * mb" as pid, victim_mb
| stats count() as reaps, min(victim_mb), avg(victim_mb), max(victim_mb)'

# ECS メモリ使用率
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name MemoryUtilization \
  --dimensions Name=ClusterName,Value=prd-v030DecidimCluster Name=ServiceName,Value=prd-v030SidekiqService \
  --period 10800 --statistics Maximum ...

# 再起動の履歴（デプロイ由来か障害由来かの判別に使う）
aws ecs describe-services --cluster prd-v030DecidimCluster --services prd-v030SidekiqService \
  --query 'services[0].events[].[createdAt,message]' --output text
aws ecs describe-task-definition --task-definition prd-v030SidekiqTaskDefinition:3 \
  --query 'taskDefinition.[revision,registeredAt]'
```

## 実測サマリ

| 項目 | 実測値 |
|---|---|
| app タスク | cpu 2048 / memory **4096 MiB**（nginx と共有、コンテナ個別上限なし） |
| `WEB_CONCURRENCY` | `4`（`decidim-cfj-cdk/lib/decidim-stack.ts:190` で全ステージ固定） |
| PWK 閾値 | **2764.8 MiB**（`config/puma.rb:27` `ram=3072` × `:29` `percent_usage=0.9`） |
| Puma 合計 RSS（7日, n=10,078） | min 1741 / p50 **2558** / p90 2722 / p95 **2741** / p99 2760 / **max 2764.73** |
| OOM reap | **7日で9回**（約1.3回/日）。犠牲 worker は 655〜684 MiB（平均668） |
| reap 時の合計 | 平均 2769 / ピーク 2777 MiB |
| ECS MemoryUtilization (app) | Average p95 62.8% / **max 64.2%**（≒ 2630 MiB） |
| sidekiq タスク | cpu 512 / memory **2048 MiB**（prd）、**1024 MiB**（dev/staging） |
| ECS MemoryUtilization (sidekiq) | Average p95 71.4% / **Maximum max 93.2%**（≒ 1910 MiB） |
| **コンテナ別メモリ**（Container Insights, 3日, n≈1,490） | `nginxContainer`: avg 27.0 / p95 **28.0** / max **30.0 MiB**<br>`appContainer`: avg 2282 / p95 **2578.8** / max **2598.0 MiB** |
| コンテナ個別のメモリ上限 | **nginx / app とも未設定**（タスクの 4096 MiB を自由に奪い合う） |
| Redis | `cache.t3.medium` × 2、**Evictions 0 / メモリ使用率 max 2.8%** |

---

## 問題1 🔴 PumaWorkerKiller の `ram` が実態と乖離し、無駄に worker を殺している

### 機序

PWK の測定実装（`puma_worker_killer-1.0.0/lib/puma_worker_killer/puma_memory.rb`）:

```ruby
def get_total(workers = set_workers)
  master_memory = GetProcessMem.new(Process.pid).mb
  worker_memory = workers.values.inject(:+) || 0
  worker_memory + master_memory          # ← RSS の単純合計
end
```

`GetProcessMem` はプロセスごとの **RSS** を読む。RSS は「そのプロセスが参照している物理ページ」なので、
master と 4 worker が共有するページ（Ruby バイナリ、libc、mmap された gem の .so 等）が **5回カウントされる**。
一方 ECS/cgroup は実物理メモリを測るので共有ページは1回。

### 実測での裏付け

| 測定者 | 値 | 割合 |
|---|---|---|
| PWK の認識 | p95 **2741 MiB** | 閾値 2764.8 に対し **99.1%** |
| ECS の実測 | max **64.2%** ≒ **2630 MiB** | コンテナ 4096 に対し **64.2%** |

**Container Insights のコンテナ別実測**（3日, n≈1,490）で過大計上量が確定した:

| | PWK の報告 | appContainer の実測(cgroup) | **過大計上** |
|---|---|---|---|
| p95 | 2741 MiB | **2578.8 MiB** | **162.2 MiB** |
| max | 2764.73 MiB | **2598.0 MiB** | **166.7 MiB** |

`nginxContainer` は avg 27.0 / p95 28.0 / **max 30.0 MiB** と極めて安定しており、
appContainer 2598 + nginx 30 = **2628 MiB** が ECS MemoryUtilization の max 64.2%（≒2630 MiB）と一致する。
→ **PWK の過大計上は約 165 MiB で確定**（推定値ではなく実測）。

**`max_mb = 2764.73` が閾値 2764.8 とほぼ完全に一致している** ＝ メモリが自然に頭打ちになっているのではなく
**reaper に叩き落とされている**。

### 実害

7日間で **9回の OOM reap**。そのたびに `preload_app!` 無効（問題3）のため再起動 worker が
Decidim をフルロードし直し、数十秒間 4 worker 中1つが不在になる。

```
PWK の認識:  2769 / 2764.8 = 100.2%  →  「限界だ、殺せ」
実際の使用:  2630 / 4096   =  64.2%  →  1466 MiB 余っている
```

### 対処 → 「問題1の解決案」（後述）を参照

---

## 問題2 🟠 PWK と ECS オートスケーリングの発火順序が逆

`decidim-cfj-cdk/lib/decidim-stack.ts:337-338` で `scaleOnMemoryUtilization` の目標 70%（= 2867.2 MiB）を
設定しているが、PWK が **2764.8 で先に worker を殺してメモリを下げてしまう**ため、
**メモリ由来のスケールアウトが一度も発動しない**。

```
現状:   PWK reap 2764.8  →  ECS scale-out 2867.2  →  OOM kill 4096
         ↑ 先に発火              ↑ 到達しない（デッドコード）
```

負荷が高まったときに「台を増やす」のではなく「worker を殺す」という逆方向の挙動になる。
問題1の対処で自動的に解消する。

---

## 問題3 🟠 `preload_app!` が無効 — CoW が効かず再起動も遅い

`config/puma.rb:53` がコメントアウトされている（**main と `upgrade/decidim-0.31` で差分ゼロ**）。

```ruby
# preload_app!
```

`preload_app!` があれば master がアプリをロードしてから fork するため worker は Copy-on-Write で親のメモリを
共有する。無効だと **各 worker が独立に Decidim をフルロードする**。

実測で worker 1つあたり **655〜684 MiB**、4つで約 2670 MiB。ここに共有はほぼない。
また PWK に殺された worker の再起動に数十秒かかる（実効容量 25% 減）。

### 対処

有効化するとベースメモリが大きく下がり再起動も高速化する。
ただし `before_fork` での PWK 起動、DB/Redis のコネクション再確立の挙動が変わるため
**必ず単独の変更として検証すること**（問題1の対処とは別コミット・別デプロイ）。

---

## 問題4 🔴 `Decidim::OpenDataJob` が上流のバグで常時失敗し、オープンデータが生成されていない

> **【2026-08-26 全面改訂】** 当初「sidekiq のメモリリークで定期的に OOM 死」と記載していたが、
> **誤りだった**。7日窓のデータだけを見て上昇局面をリークと誤認したもの。
> 30日窓とジョブログの集計により、真因は**上流 decidim の nil ガード漏れ**と判明した。

### 集計結果（30日、`prd-v030-decidim-sidekiqLogGroup`）

```
Decidim::OpenDataJob   start  6,215
                       ├─ done      588  ( 9.5%)  成功
                       ├─ fail    5,565  (89.5%)  例外で失敗
                       └─ 差分       62  ( 1.0%)  終端ログなし（OOM 候補）
```

失敗 5,565件の内訳:

| エラー | 件数 | 割合 |
|---|---|---|
| **`NoMethodError`**（`undefined method 'justification' for nil`） | **5,536** | **99.5%** |
| `Errno::ENOENT` | 27 | 0.5% |
| `ActiveStorage::IntegrityError` | 2 | 0.04% |

他ジョブとの比較（完走率）:

| ジョブ | start | done | 完走率 |
|---|---|---|---|
| **`Decidim::OpenDataJob`** | **6,215** | **588** | **9.5%** 🔴 |
| `Decidim::EmailNotificationsDigestGeneratorJob` | 239,355 | 239,355 | 100% |
| `Decidim::Admin::DestroyPrivateUsersFollowsJob` | 22,718 | 22,718 | 100% |
| `Decidim::FindAndUpdateDescendantsJob` | 6,917 | 6,917 | 100% |
| `Decidim::ExportJob` | 122 | 122 | 100% |

**OOM は「あったとしても 62件以下（1.0%）」**。しかもこの62件には
クエリ窓の境界やログ欠損も含まれるため、実際はさらに少ない。

### 根本原因: 上流 decidim の nil ガード漏れ

**collection の絞り込み条件と serializer の前提が別カラムを見ている。**

```ruby
# decidim-core/lib/decidim/core.rb:598-605
CoreDataManifest.new(
  name: :moderated_users,
  collection: lambda { |organization|
    Decidim::UserModeration.joins(:user)
      .where(decidim_users: { decidim_organization_id: organization.id })
      .where.not(decidim_users: { blocked_at: nil })      # ← blocked_at で絞る
  },
  serializer: Decidim::Exporters::OpenDataBlockedUserSerializer,
  ...
)
```

```ruby
# decidim-core/app/serializers/decidim/exporters/open_data_blocked_user_serializer.rb:19-20
block_reasons: resource.blocking.justification,               # ← nil ガードなし
blocking_user: resource.blocking.blocking_user.presenter.name
```

```ruby
# decidim-core/app/models/decidim/user.rb:20
has_one :blocking, class_name: "Decidim::UserBlock",
        foreign_key: :id, primary_key: :block_id, dependent: :destroy
```

→ **`blocked_at` は入っているが `block_id` が NULL（または参照先の `UserBlock` が削除済み）の
ユーザーが1件でもあると `resource.blocking` が nil を返し、例外になる。**

`moderated_users` は `core_data_manifests` の先頭付近で処理されるため、ZIP 生成の初期段階で落ち、
**提案も会議もユーザーも、何ひとつ出力されない。**

### 連鎖の全体像

```
[原因] OpenDataBlockedUserSerializer が resource.blocking の nil を想定していない
      ↓
[結果1] moderated_users の処理で必ず例外 → ZIP 全体が生成されない（完走率 9.5%）
      ↓
[結果2] /open-data/download が 302 を返す（ActiveStorage に添付が無い）
      ↓
[結果3] OpenDataController#download が 302 の直前に schedule_open_data_generation を呼ぶため
        ダウンロードリンクがクリックされるたびにジョブが再投入される
      ↓
[結果4] cron(1日1回×組織数) + アクセス駆動 + Sidekiq リトライ25回 で
        start が 170〜331件/日 に膨張（デッドキュー入り 66件も確認）
      ↓
[結果5] 大量のジョブが exports キューを占有し sidekiq の CPU が 100% に張り付く
```

### 実害の確認

```bash
$ curl -sI https://kakogawa.diycities.jp/open-data/download
HTTP/2 302
location: https://kakogawa.diycities.jp/open-data
```

`OpenDataController#download`（0.30.9）は添付が無いとき 302 を返す実装なので、
**302 = オープンデータが一度も生成できていない**ことを意味する。
`/open-data` ページには19種類のダウンロードリンク（results / proposals / meetings / users …）が
並んでいるが、**すべてリダイレクトされる**。

実地検証: ユーザーが `/open-data` からダウンロードをクリックしたところ、
2026-08-26 07:28:39 に `OpenDataJob` が enqueue され、**0.089秒で `NoMethodError` により fail**した
（`retry_count: 5`、`arguments: [gid://decidim-app/Decidim::Organization/1, nil]`）。
仮説どおりの挙動を実測で確認。

### 🔴 アップグレードでは直らない

| バージョン | `open_data_exporter.rb` | シリアライザの nil ガード |
|---|---|---|
| v0.30.9 | 238行 | ❌ なし |
| v0.31.7 | 246行 | ❌ なし（差分は README のメタデータ追加のみ） |
| v0.32.1 | 246行 | ❌ なし（**v0.31.7 と完全に同一・差分ゼロ**） |

**0.31 / 0.32 へ上げてもこの問題は残る。cfj 側で対処が必要。**

### 対処（優先順）

| # | 内容 | 効果 |
|---|---|---|
| **①** | **`OpenDataBlockedUserSerializer` を cfj 側で override して nil ガードを入れる**<br>`resource.blocking&.justification` / `resource.blocking&.blocking_user&.presenter&.name` | **完走率 9.5% → ほぼ100% の見込み**。ファイルが生成されれば 302 も止まり、アクセス駆動の再投入も自然に収束する |
| **②** | 上流 decidim へ報告 | 0.32.1 でも未修正のため価値が高い |
| **③** | データ側の確認: `blocked_at IS NOT NULL AND block_id IS NULL` の件数と発生経緯 | 根本。①があれば緊急ではない |
| ④ | `OpenDataExporter` のメモリ最適化 | **①の後に再測定してから判断**。OOM が主因でないと分かったため優先度は低い |

### 参考: `OpenDataExporter` のメモリ設計（④の対象、緊急ではない）

主因ではないと判明したが、実装上の問題は実在するので記録する。
`decidim-core/app/services/decidim/open_data_exporter.rb`（0.30.9 / 0.31.7 / 0.32.1 で同一）:

1. **`data_for_core`（:59-66）** — `collection` を全件一括ロード。`find_in_batches` なし。
   `users` / `moderated_users` / `moderations` がここを通る
2. **`data_for_participatory_space`（:118-128）** — 全空間の全件を `flat_map` で1配列に結合
3. **`data_for_component`（:82-116）** — 100件ずつ一時ファイルへ逃がす良い実装だが、
   最後に `data << CSV.generate_line(...)` で**全行を1つの String に再連結**して台無しにしている
4. **`data_for_all_resources`（:40-57）** — `Zip::OutputStream.write_buffer` でメモリ上に ZIP を構築し、
   `buffer.string` でさらに String コピーを作る

`OpenDataJob` は `path` にファイルを書いてから ActiveStorage に添付する設計なので、
④に着手するなら `Zip::File.open(path, create: true)` でディスクへ直接書くだけでもピークは大きく下がる。

## 問題5 🟠 app サービスも unhealthy で置換されている

```
2026-08-21T02:37:35  has started 1 tasks. Amazon ECS replaced 1 tasks due to an unhealthy status.
2026-08-14T16:13:37  has started 1 tasks. Amazon ECS replaced 1 tasks due to an unhealthy status.
```

デプロイ（08-13）以降に **2回**、ヘルスチェック失敗でタスクごと置換されている。
`desiredCount: 1` かつ `minCapacity: 1` のため、**置換中はサービスが実質1タスクしかない状態**になる。

問題1の worker 殺し（4 worker 中1つ不在＋数十秒のフルロード）がヘルスチェックのタイムアウトを
誘発している可能性は十分にある。**因果の確定にはヘルスチェック設定（interval / timeout /
unhealthyThreshold / healthyThreshold）との突き合わせが必要**（未実施）。

問題1の対処後に再発するかを観察するのが最も安上がりな切り分け。

---

## 問題6 🟡 Redis の `maxmemory-policy` が `volatile-lru`（潜在リスク）

sidekiq が起動のたびに警告を出している:

```
WARNING: Your Redis instance will evict Sidekiq data under heavy load.
The 'noeviction' maxmemory policy is recommended (current policy: 'volatile-lru').
```

`decidim-cfj-cdk/lib/elasticache-stack.ts:27` で明示設定:

```typescript
properties: { 'maxmemory-policy': 'volatile-lru' }
```

かつ `decidim-stack.ts:133-136` で **4つの Redis URL が全て同一インスタンス**を指す:

```typescript
REDIS_URL:       `redis://${props.cache}:6379`,   // Sidekiq ジョブキュー
REDIS_CACHE_URL: `redis://${props.cache}:6379`,   // Rails キャッシュ + セッション
DECIDIM_SPAM_DETECTION_BACKEND_USER_REDIS_URL:     同上
DECIDIM_SPAM_DETECTION_BACKEND_RESOURCE_REDIS_URL: 同上
```

**キャッシュ・セッション・ジョブキューが1つの Redis を共有している。**
`volatile-lru` は TTL 付きキーだけを退避対象にするため、メモリ逼迫時は
**TTL を持つセッションとキャッシュが先に消える**（＝ランダムなログアウト）。
Sidekiq のキューは TTL なしなので消えない。

### ただし現状は問題化していない

| メトリクス | 7日間の実測 |
|---|---|
| **Evictions** | **0** |
| DatabaseMemoryUsagePercentage | 最大 **2.8%** |
| BytesUsedForCache | 最大 約 **70.6 MB**（cache.t3.medium の約 3.09 GiB に対して） |

余裕が 97% あるため**今すぐの実害はない**。ジョブのバックログが肥大したときに初めて顕在化する
**潜在リスクとして記録**する。

---

## 問題7 🟡 YJIT を有効化する余地がない（0.32 アップグレードに直結）

`load_defaults 7.2` は `self.yjit = true` を設定する。しかし:

- app: PWK 閾値の **99.1%**
- sidekiq: **93.2%**

**YJIT の追加分（worker あたり数十〜128 MiB）を吸収する余地がない。**
`decidim-0.31-remaining-work.md` 付録 A-2 の通り、切替時は `config.yjit = false` を明示する。

原因は YJIT ではなく問題1〜4なので、**それらを直せば余地が生まれる**。

---

# 問題1の解決案（環境差を考慮）

## 現状の構造的欠陥

```
config/puma.rb:27                         decidim-cfj-cdk/config/<stage>.json
  config.ram = 3072   ← ハードコード         ecs.mainApp.memory = 4096
        ↑                                            ↑
        └──────── 別リポジトリ。連動しない ───────────┘
```

- **どの環境の実態とも一致していない**（全ステージ 4096 に対して 3072）
- config json を変えても `puma.rb` は追従しない。**変更がサイレントに無効化される**
- 逆に `puma.rb` を直しても、将来メモリを増減したときに再びズレる

### 各環境の実メモリ（`origin/main` 時点）

| ステージ | `mainApp.memory` | `sidekiq.memory` |
|---|---|---|
| dev | 4096 | **1024** |
| staging | 4096 | **1024** |
| prd-v030 | 4096 | 2048 |
| CDK 既定値 | `DEFAULT_MAIN_APP_MEMORY = 4096` | `DEFAULT_SIDEKIQ_MEMORY = 2048` |
| ローカル (docker compose) | **上限なし** | — |

app は現時点で全て 4096 だが、**sidekiq は環境差がある**。将来 app 側も分かれる可能性がある。

## 提案: CDK を単一の情報源にして ENV で注入する

### ① CDK 側（`decidim-cfj-cdk/lib/decidim-stack.ts`）

タスク定義のメモリ値を変数に切り出し、**appContainer にだけ**注入する
（nginx と sidekiq は Puma を動かさないので不要）。

```typescript
// タスク定義の直前で変数化（現状 :101-102 のインライン式を切り出す）
const mainAppMemory = props.ecs.mainApp?.memory ?? DEFAULT_MAIN_APP_MEMORY;

const taskDefinition = new ecs.FargateTaskDefinition(this, 'decidimTaskDefinition', {
  cpu: props.ecs.mainApp?.cpu ?? DEFAULT_MAIN_APP_CPU,
  memoryLimitMiB: mainAppMemory,        // ← 変数を使う
  family: `${props.stage}DecidimTaskDefinition`,
  taskRole: backendTaskRole,
  executionRole: backendTaskRole,
});

// :219-222 の appContainer に追加（DecidimContainerEnvironment は共有なので触らない）
taskDefinition.addContainer('appContainer', {
  environment: {
    ...DecidimContainerEnvironment,
    PUMA_WORKER_KILLER_RAM_MB: String(mainAppMemory),   // ← 追加
    // 既存の env ...
  },
  // ...
});
```

### ② アプリ側（`config/puma.rb`）

```ruby
before_fork do
  PumaWorkerKiller.config do |config|
    # コンテナに割り当てられた実メモリ量(MiB)。CDK が appContainer に注入する。
    # 未注入時（ローカル等）は保守的な既定値を使う。
    config.ram = ENV.fetch("PUMA_WORKER_KILLER_RAM_MB", 3072).to_i

    # Puma が使ってよい割合。nginx・ECS agent の使用分と、
    # PWK が RSS を単純合計することによる過大計上(実測 約160-180MiB)の余裕を見る。
    config.percent_usage = ENV.fetch("PUMA_WORKER_KILLER_PERCENT_USAGE", 0.8).to_f

    config.frequency = 60
    config.rolling_restart_frequency = 24 * 60 * 60
    config.reaper_status_logs = true
    config.pre_term = lambda do |worker|
      SlackChatMessenger.notify(channel: ENV.fetch('SLACK_MESSAGE_CHANNEL', nil), message: "[#{Rails.env}] Worker #{worker.index}(#{worker.pid}) being killed")
      puts "Worker #{worker.index}(#{worker.pid}) being killed"
    end
  end
  PumaWorkerKiller.start
end
```

**`percent_usage` を 0.9 → 0.8 に下げる点が重要。**
`ram` を実メモリ（4096）に合わせるだけで 0.9 のままだと閾値が 3686 MiB になり、
実使用換算で約 3556 MiB（コンテナの 87%）と OOM に近づきすぎる。

### 閾値の計算根拠

**Container Insights のコンテナ別実測で確定した補正値:**
- PWK の過大計上: **約 165 MiB**（p95 で 162.2 / max で 166.7）
- nginx の実使用: **30 MiB**（max。avg 27・p95 28 と極めて安定）

```
PWK 閾値       = 4096 × 0.8 = 3276.8 MiB
実 appContainer = 3276.8 − 165 = 約 3112 MiB
タスク全体     = 3112 + 30(nginx) = 約 3142 MiB = コンテナの 76.7%
```

※ `percent_usage = 0.85` なら閾値 3481.6 → タスク全体 約 3347 MiB（81.7%）で余裕 750 MiB。
問題4（sidekiq のリーク）が示すとおり Decidim のプロセスは想定外に伸びうるため、
**まず 0.8 で運用し、reap がゼロで安定してから 0.85 を検討する**のが安全。

| | 現状 | 提案後 |
|---|---|---|
| PWK 閾値 | 2764.8 MiB | **3276.8 MiB** |
| 実使用換算（タスク全体） | 約 2635 MiB（**64%**） | 約 3147 MiB（**77%**） |
| ECS scale-out(2867.2) との順序 | **PWK が先（逆）** | **scale-out が先（正）** |
| OOM kill(4096) までの余裕 | 1466 MiB | **954 MiB** |
| 期待される reap 頻度 | 1.3回/日 | **ほぼゼロ**（p99 2760 < 3276.8） |

### 環境差への追従

- **app**: 現時点では全ステージ 4096 なので値は同じだが、
  今後 `config/<stage>.json` の `mainApp.memory` を変えれば **CDK デプロイだけで自動追従**する
- **ローカル (docker compose)**: `config/puma.rb:46` が
  `workers ENV.fetch("WEB_CONCURRENCY", 2) unless Rails.env.development?` なので
  development では clustered mode にならず **`before_fork` が発火しない＝PWK は動かない**。
  fallback 値 3072 は使われない
- ただし **ローカルで `RAILS_ENV=production` 検証をする場合**は fallback 3072 が効く。
  docker compose に `mem_limit` がないためホストのメモリ次第になる点は許容する
  （必要なら `compose.override.yml` で `PUMA_WORKER_KILLER_RAM_MB` を指定）

### 副案: cgroup から直接読む

CDK との連動を不要にする方法。ただし Fargate の cgroup 実装差異（v1/v2、`max` の扱い）を
吸収する必要があり、ENV 方式より脆い。**副案として記録するに留める**。

```ruby
def container_memory_mb
  raw = File.read("/sys/fs/cgroup/memory.max").strip rescue nil          # cgroup v2
  raw = File.read("/sys/fs/cgroup/memory/memory.limit_in_bytes").strip rescue nil if raw.nil? || raw == "max"
  return nil if raw.nil? || raw == "max"
  bytes = raw.to_i
  return nil if bytes <= 0 || bytes > 64 * 1024**3   # 未設定時の巨大値を弾く
  bytes / 1024 / 1024
end
```

### 検証手順

```bash
# デプロイ後、ENV が注入されているか
aws ecs describe-task-definition --profile decidim --region ap-northeast-1 \
  --task-definition prd-v030DecidimTaskDefinition \
  --query 'taskDefinition.containerDefinitions[?name==`appContainer`].environment[?name==`PUMA_WORKER_KILLER_RAM_MB`]'

# PWK が新しい閾値を使っているか（reap ログの "out of max: N mb"）
aws logs filter-log-events --profile decidim --region ap-northeast-1 \
  --log-group-name prd-v030-decidim-serviceLogGroup \
  --filter-pattern '"out of max"' --query 'events[-3:].message'
# → "out of max: 3276.8 mb" になっていること

# 1週間後、reap がゼロになったかを再測定（調査コマンド参照）
```

---

# 対応の順序

| # | 対応 | リスク | 0.31/0.32 との関係 |
|---|---|---|---|
| 1 | **PWK の環境連動化**（CDK の ENV 注入 + `puma.rb` 修正 + `percent_usage` 0.8） | ほぼゼロ（殺されにくくなる方向のみ） | **0.31 切替前に本番投入推奨**。歪んだ設定を新スタックに引き継がない |
| 2 | **sidekiq memory 引き上げ**（prd 2048→3072、dev/staging 1024→2048） | ゼロ（コスト増のみ） | prd-v031 スタック作成時が自然 |
| 3 | sidekiq のリーク源特定 | 調査のみ | 独立。Sidekiq 7 化（0.32 で必須）と併せて |
| 4 | `preload_app!` 有効化 | 中（fork 挙動が変わる） | **単独検証**。0.31 とは切り離す |
| 5 | app の unhealthy 置換の因果特定 | 調査のみ | 1 を入れると自然解消する可能性。まず観察 |
| 6 | `maxmemory-policy` の見直し | 低 | 潜在リスク。急がない |
| 7 | YJIT 有効化 | — | 1〜4 の後。0.32 で再評価 |

---

# 未確認事項

1. **問題5 の因果**。ALB のヘルスチェック設定（interval / timeout / unhealthyThreshold）を確認していない。
   問題1の対処後に再発するかの観察が最も安上がりな切り分け
2. **問題4 のリーク源**。ジョブ種別との相関を取っていない。
   ECS の停止タスク履歴は保持期間の関係で空だったため、`stoppedReason` による OOM の直接確認はできていない
   （デプロイなしの再起動 + ヘルスチェック非搭載 + 93.2% ピークという状況証拠のみ）
3. ~~PWK の過大計上量~~ **【2026-08-25 解消】** Container Insights のコンテナ別実測により
   **約 165 MiB で確定**（PWK p95 2741 vs appContainer p95 2578.8）。
   ただし **`preload_app!` を有効化すると共有ページが増えて過大計上はさらに大きくなる**ため、
   問題3に着手する際は `percent_usage` の再調整が要る
4. ~~nginx の実使用量~~ **【2026-08-25 解消】** `nginxContainer` は avg 27.0 / p95 28.0 / **max 30.0 MiB**。
   コンテナ個別の memoryLimit は未設定だが、Container Insights が有効なため
   `/aws/ecs/containerinsights/prd-v030DecidimCluster/performance` から取得できた
5. dev/staging の実メモリ実測は未取得（本調査は prd-v030 のみ）

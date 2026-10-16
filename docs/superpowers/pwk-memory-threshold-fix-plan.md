# PumaWorkerKiller メモリ閾値の是正 実行計画

作成日: 2026-08-25
対象: `decidim-cfj/config/puma.rb` + `decidim-cfj-cdk/lib/decidim-stack.ts`
関連: `prd-infra-issues-2026-08.md`（問題1）/ `decidim-0.31-remaining-work.md` 付録A-2（YJIT）

---

## 1. 何が起きているか

本番（prd-v030）で **PumaWorkerKiller が 7日で9回、不要に worker を強制終了している**。
コンテナには 1466 MiB 余っているのに、設定値が実態と乖離しているため。

### 根拠となる実測（すべて AWS から取得）

| 項目 | 値 | 取得元 |
|---|---|---|
| app タスク | cpu 2048 / **memory 4096 MiB** | `describe-task-definition` |
| PWK 閾値 | **2764.8 MiB** | `puma.rb:27` `ram=3072` × `:29` `percent_usage=0.9` |
| Puma 合計 RSS（7日, n=10,078） | p50 2558 / **p95 2741** / p99 2760 / **max 2764.73** | CloudWatch Logs Insights |
| **OOM reap** | **7日で9回**（約1.3回/日） | 同上 |
| ローリング再起動 | 7日で28回（4 worker × 7日、**設計通り**） | 同上 |
| 犠牲 worker のサイズ | min 655 / avg 668 / max 684 MiB | 同上 |
| `nginxContainer` 実使用 | avg 27.0 / p95 28.0 / **max 30.0 MiB** | Container Insights |
| `appContainer` 実使用 | avg 2282 / p95 2578.8 / **max 2598.0 MiB** | Container Insights |
| ECS MemoryUtilization (app) | Average p95 62.8% / **max 64.2%** | CloudWatch |

`max_mb = 2764.73` が閾値 2764.8 とほぼ一致 ＝ **メモリが自然に頭打ちになっているのではなく reaper に叩き落とされている**。

### 機序: PWK は RSS を単純合計するため過大計上する

```ruby
# puma_worker_killer-1.0.0/lib/puma_worker_killer/puma_memory.rb
def get_total(workers = set_workers)
  master_memory = GetProcessMem.new(Process.pid).mb
  worker_memory = workers.values.inject(:+) || 0
  worker_memory + master_memory          # ← RSS の単純合計
end
```

RSS は「そのプロセスが参照している物理ページ」なので、master と 4 worker が共有するページ
（Ruby バイナリ、libc、mmap された gem の .so 等）が **5回カウントされる**。cgroup は1回。

**過大計上量は実測で確定:**

| | PWK の報告 | appContainer の実測(cgroup) | 過大計上 |
|---|---|---|---|
| p95 | 2741 MiB | 2578.8 MiB | **162.2 MiB** |
| max | 2764.73 MiB | 2598.0 MiB | **166.7 MiB** |

検算: appContainer 2598 + nginx 30 = **2628 MiB** ≒ ECS MemoryUtilization max 64.2%（2630 MiB）。

### 閾値の計算式（実装で確認）

```ruby
# puma_worker_killer.rb
def reaper(ram = self.ram, percent_usage = self.percent_usage, ...)
  Reaper.new(ram * percent_usage, ...)     # @max_ram = ram × percent_usage
end

# reaper.rb — 60秒ごと(frequency=60)に判定し、超過時は「最大の worker 1つ」を TERM
if total > @max_ram
  @pre_term&.call(largest_worker)          # cfj は Slack 通知
  @cluster.term_worker(largest_worker)
```

---

## 2. 構造的な欠陥

```
decidim-cfj/config/puma.rb:27            decidim-cfj-cdk/config/<stage>.json
  config.ram = 3072   ← ハードコード        ecs.mainApp.memory = 4096
        ↑                                          ↑
        └────── 別リポジトリ。連動しない ───────────┘
```

- **どの環境の実態とも一致していない**（全ステージ 4096 に対して 3072）
- config json を変えても `puma.rb` は追従しない。**変更がサイレントに無効化される**
- 単に `3072 → 3600` と書き換えるだけでは、将来メモリを増減したときに同じ問題が再発する

### 各環境の実態（`origin/main` 時点 + AWS 実機）

| ステージ | `mainApp.memory` | クラスタ | 稼働 | Puma RSS p95 | 閾値超過 |
|---|---|---|---|---|---|
| **prd-v030** | 4096 | 実在 | 1タスク | **2741 MiB** | **常時。9回/週 reap** |
| staging | 4096 | 実在 | **desiredCount=0（停止中）** | 1827 MiB | なし（閾値まで938 MiB） |
| dev | 4096 | **存在しない**（config のみ） | — | — | — |
| CDK 既定値 | `DEFAULT_MAIN_APP_MEMORY = 4096` | — | — | — | — |

→ **実害が出ているのは prd のみ**。ただし設定の構造的欠陥は全環境共通。
→ `WEB_CONCURRENCY` は `decidim-stack.ts:190` で `'4'` に全ステージ固定。

---

## 3. 方針: CDK を単一の情報源にして ENV で注入する

### Phase 1: アプリ側（`decidim-cfj`）

`config/puma.rb` の `before_fork` ブロックを変更する。

```ruby
before_fork do
  PumaWorkerKiller.config do |config|
    config.ram = ENV.fetch("PUMA_WORKER_KILLER_RAM_MB", 3072).to_i
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

**変更は2行のみ**（`config.ram` と `config.percent_usage`）。他は現状維持。

- `config.ram` は PWK のドキュメント上「利用可能な RAM の量」なので、**コンテナの実メモリを入れるのが素直**
- `config.percent_usage` が安全マージンを表現する。nginx（30 MiB）と PWK の過大計上（165 MiB）を
  ここに吸収させる
- フォールバック 3072 は現状値。ENV 未注入でも**挙動が変わらない**

### Phase 2: CDK 側（`decidim-cfj-cdk`）

`lib/decidim-stack.ts` を2箇所変更する。

```typescript
// :99-106 タスク定義。インライン式を変数に切り出す
const mainAppMemory = props.ecs.mainApp?.memory ?? DEFAULT_MAIN_APP_MEMORY;

const taskDefinition = new ecs.FargateTaskDefinition(this, 'decidimTaskDefinition', {
  cpu: props.ecs.mainApp?.cpu ?? DEFAULT_MAIN_APP_CPU,
  memoryLimitMiB: mainAppMemory,          // ← 変数を使う
  family: `${props.stage}DecidimTaskDefinition`,
  taskRole: backendTaskRole,
  executionRole: backendTaskRole,
});
```

```typescript
// :219-241 appContainer の environment に追加
taskDefinition.addContainer('appContainer', {
  image: new ecs.EcrImage(decidimRepository, props.tag),
  environment: {
    ...DecidimContainerEnvironment,
    ...{
      PUMA_WORKER_KILLER_RAM_MB: String(mainAppMemory),   // ← 追加
      NEW_RELIC_AGENT_ENABLED: isPrd(props.stage) ? 'true' : 'false',
      // 以下既存 ...
    },
  },
```

**`DecidimContainerEnvironment`（共有）には入れない。** nginx と sidekiq は Puma を動かさないため。

---

## 4. 閾値の変化と根拠

```
PWK 閾値        = 4096 × 0.8 = 3276.8 MiB   （PWK の過大計上込みの見かけ値）
実 appContainer = 3276.8 − 165 = 約 3112 MiB
タスク全体      = 3112 + 30(nginx) = 約 3142 MiB = コンテナの 76.7%
```

| | 現状 | 提案後 |
|---|---|---|
| PWK 閾値（見かけ） | 2764.8 MiB | **3276.8 MiB** |
| 実使用換算（タスク全体） | 約 2628 MiB（**64.2%**） | 約 3142 MiB（**76.7%**） |
| ECS scale-out(70% = 2867.2) との順序 | **PWK が先（逆）** | **scale-out が先（正）** |
| OOM kill(4096) までの余裕 | 1466 MiB | **954 MiB** |
| 期待される reap 頻度 | 1.3回/日 | **ほぼゼロ**（p99 2760 < 3276.8） |

### 発火順序が正しくなる

```
現状:   PWK reap 2764.8  →  ECS scale-out 2867.2  →  OOM kill 4096
         ↑ 先に発火              ↑ 到達しない（デッドコード）

提案後: ECS scale-out 2867.2  →  PWK reap 3276.8  →  OOM kill 4096
         ↑ まず増やす             ↑ 安全弁          ↑ 最後
```

※ ECS は**実メモリ**で測るので scale-out の 2867.2 は実値。PWK の 3276.8 は見かけ値
（実換算 3142）。両者は同じ土俵ではないため、実換算で比較して順序を確認している。

### なぜ 0.9 のままではダメか

`ram` を 4096 にして `percent_usage` を 0.9 のままにすると閾値 3686.4 →
実換算 3521 + nginx 30 = **3551 MiB = コンテナの 86.7%**。OOM kill まで 545 MiB しかなく、
安全弁として機能しない。

### なぜ 0.8 か（0.85 ではなく）

`percent_usage = 0.85` なら実換算 3347 MiB（81.7%）、余裕 749 MiB。悪くはないが、
**問題4（sidekiq のメモリリーク）が示すとおり Decidim のプロセスは想定外に伸びうる**。
まず 0.8 で運用し、reap がゼロで安定してから 0.85 を検討する。

### 閾値を上げても暴走しない理由

閾値を上げると「reap が効かずメモリが OOM まで伸びる」のではないかという懸念があるが、
**`rolling_restart_frequency = 24 * 60 * 60` が全 worker を24時間ごとに再起動する**
（実測で7日28回＝設計通り動作中）。これが上限を画するため、閾値を上げても
無制限に伸びることはない。

---

## 5. デプロイ順序

**どちらを先にデプロイしても安全**（片側だけでは現状と同じ挙動になる）。

| 順序 | 起きること |
|---|---|
| CDK が先 | ENV は注入されるがアプリが読まない → **現状のまま**（3072 × 0.9） |
| アプリが先 | ENV が無いのでフォールバック 3072、`percent_usage` だけ 0.8 に → 閾値 **2764.8 → 2457.6 に下がる**。⚠️ reap が増える |

→ **CDK を先にデプロイするのが安全**。アプリ先行だと一時的に閾値が下がって reap が増える。

ただし cfj の実際のデプロイは `_deploy.yaml` がアプリイメージをビルドしてから
`cdk deploy --context tag=<tag>` を叩く形なので、**両方の PR をマージしてから1回デプロイすれば
同時に反映される**。この場合は順序を気にしなくてよい。

---

## 6. 検証手順

### デプロイ直後

```bash
export AWS_PROFILE=decidim AWS_REGION=ap-northeast-1

# ① ENV が注入されているか
aws ecs describe-task-definition --task-definition prd-v030DecidimTaskDefinition \
  --query 'taskDefinition.containerDefinitions[?name==`appContainer`].environment[?name==`PUMA_WORKER_KILLER_RAM_MB`]'
# → [[{"name":"PUMA_WORKER_KILLER_RAM_MB","value":"4096"}]]

# ② PWK が新しい閾値を使っているか（reap 発生時のログに出る）
aws logs filter-log-events --log-group-name prd-v030-decidim-serviceLogGroup \
  --start-time $(( ($(date +%s) - 3600) * 1000 )) \
  --filter-pattern '"out of max"' --query 'events[-3:].message'
# → "out of max: 3276.8 mb"

# ③ アプリ内から直接確認（reap を待たずに済む）
aws ecs execute-command --cluster prd-v030DecidimCluster --task <task-id> \
  --container appContainer --interactive \
  --command "ruby -e 'require \"puma_worker_killer\"; puts ENV[\"PUMA_WORKER_KILLER_RAM_MB\"]'"
```

### 1週間後の効果測定

```bash
# reap がゼロになったか
aws logs start-query --log-group-name prd-v030-decidim-serviceLogGroup \
  --start-time $(( $(date +%s) - 7*86400 )) --end-time $(date +%s) \
  --query-string 'filter @message like /Sending TERM to pid/
| parse @message "PumaWorkerKiller: * " as kind
| stats count() as n by kind'
# → Rolling 28 のみ、Out が 0 になっていること

# メモリ分布が上振れした位置で安定しているか
aws logs start-query --log-group-name prd-v030-decidim-serviceLogGroup \
  --start-time $(( $(date +%s) - 7*86400 )) --end-time $(date +%s) \
  --query-string 'filter @message like /PumaWorkerKiller: Consuming/
| parse @message "Consuming * mb" as mem
| stats count() as samples, pct(mem,50) as p50, pct(mem,95) as p95, pct(mem,99) as p99, max(mem) as max_mb'
```

### 監視すべき指標と閾値

| 指標 | 取得元 | 期待 | 異常時のアクション |
|---|---|---|---|
| **OOM reap 回数** | Logs `/Out of memory/` | **0/週** | 3276.8 でも超えるなら真のメモリ問題。リーク調査へ |
| Puma RSS p99 | Logs `/Consuming/` | 2800〜3100 で頭打ち | **3276 に張り付いたら**閾値がまた効いている＝要再調整 |
| ECS MemoryUtilization (app) | CloudWatch | max 70〜78% | **> 85% 持続**なら `percent_usage` を 0.75 へ戻す |
| ECS scale-out 発生 | Service Events | 高負荷時に発生するようになる | 発生自体は正常（今までデッドコードだった） |
| ALB TargetResponseTime | CloudWatch | 改善または横ばい | 悪化ならロールバック |
| `unhealthy status` 置換 | Service Events | **減るはず**（問題5の切り分け） | 増えたら別要因 |
| Slack の worker killed 通知 | `SLACK_MESSAGE_CHANNEL` | **止まるはず** | 続くなら①が反映されていない |

---

## 7. ロールバック

閾値を下げるだけなので**アプリの再デプロイ不要**でロールバックできる。

```typescript
// decidim-stack.ts で明示的に旧値を渡す
PUMA_WORKER_KILLER_RAM_MB: '3072',
```
＋ `PUMA_WORKER_KILLER_PERCENT_USAGE: '0.9'` を注入すれば完全に現状へ戻る
（そのためアプリ側も `percent_usage` を ENV 経由にしておく価値がある）。

CDK デプロイのみで戻せる = **切り戻しが速い**。

---

## 8. スコープ外（別タスク）

| 項目 | 理由 |
|---|---|
| **`preload_app!` の有効化**（問題3） | fork 挙動・DB/Redis コネクション再確立が変わる。**単独で検証すべき**。<br>⚠️ 有効化すると共有ページが増え **PWK の過大計上が 165 MiB より大きくなる**ため、<br>`percent_usage` の再調整が必要になる |
| **sidekiq のメモリ引き上げ**（問題4） | sidekiq に PWK は無い。CDK の `ecs.sidekiq.memory` の変更で独立して対応 |
| **`WEB_CONCURRENCY` の環境別化** | 現在 `'4'` 固定。メモリ変更と連動させるなら別途設計が要る |
| **nginx コンテナの要否** | PR #102 の補足に記載。次のブルーグリーン切替時に検討 |
| **YJIT 有効化** | 本件と問題3・4が片付いてから。`decidim-0.31-remaining-work.md` 付録A-2 |

---

## 9. 実施順序とタイミング

1. **decidim-cfj の PR**（`config/puma.rb` 2行）
2. **decidim-cfj-cdk の PR**（`lib/decidim-stack.ts` 2箇所 + スナップショット更新）
3. 両方マージ → **staging へ先行デプロイ**して ENV 注入を確認
   （staging は現在 `desiredCount=0` なので、確認するなら一時的に起動が必要）
4. prd へデプロイ
5. **1週間観察** → reap ゼロを確認
6. 安定後、`percent_usage` 0.85 への引き上げを検討

### 0.31 アップグレードとの関係

**0.31 の本番切替（prd-v031 スタック作成）より前に prd-v030 へ入れることを推奨。**
歪んだ閾値設定を新スタックにそのまま引き継がずに済む。
また `load_defaults 7.2` の YJIT 判断（`decidim-0.31-remaining-work.md` 付録A-2）にも
本件の結果が直接効く。

---

## 10. 未確認事項

1. **PWK の過大計上が閾値を上げた後も約165 MiB のままか**。共有ページ量はワークロードで変わりうる。
   1週間後の再測定（PWK の p95 vs Container Insights の appContainer p95）で確認する
2. **問題5（app の unhealthy 置換）との因果**。本件で reap が止まれば置換も止まるかを観察する
3. **staging での事前検証の可否**。`desiredCount=0` のため、確認には一時起動が必要
4. **ECS scale-out が実際に発火したときの挙動**。今までデッドコードだったため未経験。
   スケールアウト後にメモリが下がるかは未検証（Ruby は OS にメモリを返しにくいため、
   既存タスクのメモリは下がらない可能性が高い）

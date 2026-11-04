# Fix CloseMeetingReminder Wrong Organization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `CloseMeetingReminderGenerator#space_admins` のメモ化バグを修正し、公式ミーティングのリマインダーが正しい組織の管理者へ送られるようにする。

**Architecture:** `config/initializers/decidim_override.rb` 内で `prepend` パターンを使い、`space_admins` メソッドのみオーバーライドする。他のパッチと同じ `Rails.application.config.to_prepare` ブロック内に追記する。

**Tech Stack:** Ruby 3.2 / Rails 6.1 / decidim-meetings 0.29.2 / RSpec

---

## バグの説明

`CloseMeetingReminderGenerator#generate` は **全組織のすべての meetings コンポーネント** を処理する。
`space_admins(component)` は `@space_admins ||=` でインスタンス変数にメモ化するため、最初に処理したコンポーネントの管理者がすべての後続コンポーネントでも返ってしまう。

結果として、あるテナント（世田谷区）の管理者が別テナント（いのち会議）のミーティングリマインダーを受け取り、そのメールが受信者の組織（世田谷区）のブランドで送られる。

---

### Task 1: テストを書く

**Files:**
- Create: `spec/services/decidim/meetings/close_meeting_reminder_generator_spec.rb`

- [ ] **Step 1: フェイルするテストを作成**

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Decidim::Meetings::CloseMeetingReminderGenerator do
  subject(:generator) { described_class.new }

  describe "#generate (space_admins cross-organization bug)" do
    let(:org_a) { create(:organization) }
    let(:org_b) { create(:organization) }

    let(:admin_a) { create(:user, :admin, organization: org_a) }
    let(:admin_b) { create(:user, :admin, organization: org_b) }

    # org_a の participatory space / component
    let(:space_a) { create(:participatory_process, organization: org_a) }
    let(:component_a) { create(:meetings_component, participatory_space: space_a) }

    # org_b の participatory space / component
    let(:space_b) { create(:participatory_process, organization: org_b) }
    let(:component_b) { create(:meetings_component, participatory_space: space_b) }

    # 両組織に公式ミーティング（end_time は1日前）
    let!(:official_meeting_a) do
      create(:meeting, :published, component: component_a,
             author: org_a,
             end_time: 1.day.ago)
    end
    let!(:official_meeting_b) do
      create(:meeting, :published, component: component_b,
             author: org_b,
             end_time: 1.day.ago)
    end

    before do
      admin_a
      admin_b
    end

    it "org_b の公式ミーティングリマインダーを org_b の管理者にのみ送る" do
      # component の処理順が org_a → org_b になるよう id で確認
      expect(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later) do |record|
        # org_b ミーティングのリマインダーは org_b 管理者に限定
        if record.remindable == official_meeting_b
          expect(record.reminder.user.organization).to eq(org_b)
        end
      end.at_least(:once)

      generator.generate
    end

    it "org_a の管理者が org_b ミーティングのリマインダーを受け取らない" do
      queued_records = []
      allow(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later) do |record|
        queued_records << record
      end

      generator.generate

      org_b_meeting_reminders = queued_records.select { |r| r.remindable == official_meeting_b }
      users = org_b_meeting_reminders.map { |r| r.reminder.user }
      expect(users).not_to include(admin_a)
      expect(users).to include(admin_b)
    end
  end
end
```

- [ ] **Step 2: テストを実行してフェイルを確認**

```bash
cd /Users/ayuki/decidim-directory/decidim-cfj
bundle exec rspec spec/services/decidim/meetings/close_meeting_reminder_generator_spec.rb --no-color 2>&1 | tail -30
```

期待結果: FAIL（`admin_a` が `official_meeting_b` のリマインダーを受け取るため）

---

### Task 2: バグを修正する

**Files:**
- Modify: `config/initializers/decidim_override.rb`（末尾の `end` の直前に追記）

- [ ] **Step 3: `decidim_override.rb` の末尾 `end` の直前にパッチを追加**

`config/initializers/decidim_override.rb` のファイル末尾（最後の `end` の直前）に以下を挿入する:

```ruby
  # ----------------------------------------

  # Fix CloseMeetingReminderGenerator#space_admins cross-organization memoization bug
  # @space_admins ||= はインスタンス変数にメモ化するため、全組織をまたいで同じ管理者リストが
  # 使い回されてしまう。メモ化を除去して毎回正しい組織の管理者を返すようにする。
  module DecidimMeetingsCloseMeetingReminderGeneratorPatch
    private

    def space_admins(component)
      sa = if component.participatory_space.respond_to?(:user_roles)
             component.participatory_space.user_roles(:admin).collect(&:user)
           else
             []
           end
      global_admins = component.organization.admins
      (global_admins + sa).uniq
    end
  end

  Decidim::Meetings::CloseMeetingReminderGenerator # rubocop:disable Lint/Void

  module Decidim
    module Meetings
      class CloseMeetingReminderGenerator
        prepend DecidimMeetingsCloseMeetingReminderGeneratorPatch
      end
    end
  end
```

- [ ] **Step 4: テストを再実行してパスを確認**

```bash
cd /Users/ayuki/decidim-directory/decidim-cfj
bundle exec rspec spec/services/decidim/meetings/close_meeting_reminder_generator_spec.rb --no-color 2>&1 | tail -20
```

期待結果: 2 examples, 0 failures

---

### Task 3: Rubocop チェックとコミット

**Files:**
- `config/initializers/decidim_override.rb`
- `spec/services/decidim/meetings/close_meeting_reminder_generator_spec.rb`

- [ ] **Step 5: Rubocop を実行**

```bash
cd /Users/ayuki/decidim-directory/decidim-cfj
bundle exec rubocop config/initializers/decidim_override.rb spec/services/decidim/meetings/close_meeting_reminder_generator_spec.rb --no-color 2>&1 | tail -20
```

エラーがあれば修正してから次へ。

- [ ] **Step 6: feature ブランチを切る**

```bash
git -C /Users/ayuki/decidim-directory/decidim-cfj checkout -b fix/close-meeting-reminder-wrong-organization
```

- [ ] **Step 7: コミット**

```bash
git -C /Users/ayuki/decidim-directory/decidim-cfj add config/initializers/decidim_override.rb spec/services/decidim/meetings/close_meeting_reminder_generator_spec.rb
git -C /Users/ayuki/decidim-directory/decidim-cfj commit -m "fix: CloseMeetingReminderGenerator#space_admins のクロス組織メモ化バグを修正"
```

- [ ] **Step 8: PR 作成**

```bash
git -C /Users/ayuki/decidim-directory/decidim-cfj push origin fix/close-meeting-reminder-wrong-organization
gh -C /Users/ayuki/decidim-directory/decidim-cfj pr create \
  --title "fix: CloseMeetingReminderGenerator の space_admins メモ化バグ修正" \
  --body "$(cat <<'EOF'
## 問題

`CloseMeetingReminderGenerator#space_admins` が `@space_admins ||=` でインスタンス変数にメモ化されているため、複数組織をまたいで `generate` が走ると最初に処理した組織の管理者リストがすべての後続コンポーネントに使い回される。

**再現した事象**: いのち会議の公式ミーティングリマインダーが、世田谷区の管理者（HIGASHI Kenjiro）に対して世田谷区のブランドで送信された（2026-05-27）。

## 修正

`space_admins` メソッドのインスタンス変数メモ化を除去し、呼び出しごとに渡された `component` の組織に基づいて管理者を返すようにした。

## テスト

- 2組織を用意し、org_b の公式ミーティングリマインダーが org_a の管理者に送られないことを確認
EOF
)"
```

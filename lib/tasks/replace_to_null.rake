# frozen_string_literal: true

namespace :replace_to_null do
  # NOTE: decidim 0.32 でスペースの announcement は content block へ移設された
  # (move_announcement_to_content_block_on_assemblies / _participatory_processes)。
  # カラム自体は残っているのでこれらのタスクは落ちないが、announcement を空にしても
  # 表示には影響しない。残った旧カラムを掃除する用途でのみ意味がある。
  desc "fix space edit bug.Make all announcement columns of decidim_assemblies table null"
  task decidim_assemblies_announcement: :environment do
    Decidim::Assembly.update_all(announcement: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  desc 'fix organization edit bug.Make all "" columns of decidim_assemblies table null'
  task decidim_organization: :environment do
    Decidim::Organization.transaction do
      Decidim::Organization.all.each do |org|
        org.description = nil if org.description == ""
        org.highlighted_content_banner_short_description = nil if org.highlighted_content_banner_short_description == ""
        org.save!
      end
    end
  end

  desc 'fix participatory_processes edit bug.Make all "" columns of decidim_participatory_processes table null'
  task decidim_participatory_processes: :environment do
    Decidim::ParticipatoryProcess.transaction do
      Decidim::ParticipatoryProcess.all.each do |org|
        org.announcement = nil if org.announcement == ""
        org.save!
      end
    end
  end

  desc 'fix proposal edit bug.Make all "" columns of decidim_proposals_proposals table null'
  task decidim_proposals: :environment do
    Decidim::Proposals::Proposal.transaction do
      Decidim::Proposals::Proposal.all.each do |proposal|
        proposal.answer = nil if proposal.answer == ""
        proposal.cost_report = nil if proposal.cost_report == ""
        proposal.execution_period = nil if proposal.execution_period == ""
        proposal.save!
      end
    end
  end
end

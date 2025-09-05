# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe ReportedMailer do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, :admin, organization:, locale: "ja") }
    let(:component) { create(:component, organization:) }
    let(:reportable) { create(:proposal, title: Decidim::Faker::Localized.sentence, body: Decidim::Faker::Localized.paragraph(sentence_count: 3)) }
    let(:moderation) { create(:moderation, reportable:, participatory_space: component.participatory_space, report_count: 1) }
    let(:author) { reportable.creator_identity }
    let!(:report) { I18n.with_locale(:ja) { create(:report, moderation:, details: "bacon eggs spam") } }
    let(:decidim) { Decidim::Core::Engine.routes.url_helpers }

    before do
      if reportable.coauthorships.first.author.is_a?(Decidim::Organization)
        reportable.coauthorships.first.author.update!(name: { en: "O'Higgins" })
      else
        reportable.coauthorships.first.author.update!(name: "O'Higgins")
      end
    end

    around do |example|
      I18n.with_locale(:ja) do
        example.run
      end
    end

    describe "#report" do
      let(:mail) { described_class.report(user, report) }

      describe "email body" do
        it "includes the participatory space name" do
          expect(email_body(mail)).to include(decidim_escape_translated(moderation.participatory_space.title))
        end

        it "includes the report's reason" do
          I18n.with_locale(:ja) do
            expect(email_body(mail)).to match(I18n.t(report.reason, scope: "decidim.shared.flag_modal"))
          end
        end

        it "includes the report's details" do
          expect(email_body(mail)).to match(report.details)
        end

        it "includes the reported content" do
          expect(email_body(mail)).to match("(ID: #{reportable.id})")
          expect(email_body(mail)).to match(reportable.title["en"])
          expect(email_body(mail)).to match(reportable.body["en"])
        end

        it "renders the organization default language when the content language cannot be deduced by the reported content itself" do
          report.moderation.reportable.title = nil
          report.moderation.reportable.body = nil

          expect(email_body(mail)).to match("<b>コンテンツのオリジナル言語</b>")
          expect(email_body(mail)).to match("日本語")
        end

        context "when logo is attached" do
          let(:organization_logo) { Decidim::Dev.test_file("city.jpeg", "image/jpeg") }

          before do
            organization.logo.attach(organization_logo)
            organization.save!
          end
        end

        context "when the author is a user" do
          it "includes the name of the author and a link to their profile" do
            expect(email_body(mail)).to have_link(author.name, href: decidim.profile_url(author.nickname, host: organization.host))
          end
        end

        context "when the author is a deleted user" do
          before do
            author.nickname = ""
            author.deleted_at = 1.week.ago
            author.save!
          end

          it "includes the name of the author but no link to their profile" do
            expect(mail).to have_no_link(author.name)
          end
        end

        context "when the author is an organization" do
          let(:reportable) { create(:proposal, :official) }

          it "includes the name of the organization" do
            expect(email_body(mail)).to match(decidim_escape_translated(author.name))
          end
        end

        context "when the author is a meeting" do
          let(:meetings_component) { create(:component, manifest_name: :meetings, organization: reportable.organization) }
          let!(:meeting) { create(:meeting, component: meetings_component) }

          it "includes the title of the meeting" do
            reportable.coauthorships.destroy_all
            create(:coauthorship, coauthorable: reportable, author: meeting)

            expect(email_body(mail)).to have_content(translated(meeting.title))
          end
        end
      end
    end
  end
end

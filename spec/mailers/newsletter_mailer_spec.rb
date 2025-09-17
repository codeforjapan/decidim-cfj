# frozen_string_literal: true

require "rails_helper"

module Decidim
  describe NewsletterMailer do
    let(:user) { create(:user, name: "Sarah Connor", locale: :en, organization:) }
    let(:newsletter) do
      create(:newsletter,
             organization:,
             subject: {
               en: "Email for %{name}",
               ja: "%{name}宛のメール"
             },
             body: {
               en: "Content for %{name}",
               ja: "%{name}宛の内容"
             })
    end

    let(:organization) { create(:organization, host: "test.lvh.me", default_locale: :en) }

    describe "newsletter" do
      let(:mail) { described_class.newsletter(user, newsletter) }

      it "parses the subject" do
        expect(mail.subject).to eq("Email for Sarah Connor")
      end

      it "parses the body" do
        expect(email_body(mail)).to include("Content for Sarah Connor")
      end

      context "when the user has a different locale" do
        before do
          user.locale = "ja"
          user.save!
        end

        it "parses the subject in the user's locale" do
          expect(mail.subject).to eq("Sarah Connor宛のメール")
        end

        it "parses the body in the user's locale" do
          expect(email_body(mail)).to include("Sarah Connor宛の内容")
        end

        context "when there is no content in the user's locale" do
          let(:newsletter) do
            create(:newsletter,
                   organization:,
                   subject: {
                     en: "Email for %{name}",
                     ja: ""
                   },
                   body: {
                     en: "Content for %{name}",
                     ja: ""
                   })
          end

          it "fallbacks to the default one" do
            expect(mail.subject).to eq("Email for Sarah Connor")
            expect(email_body(mail)).to include("Content for Sarah Connor")
          end
        end
      end
    end
  end
end

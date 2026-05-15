# frozen_string_literal: true

# Disable the Decidim direct messaging (conversations) feature.
# - Makes every user reject incoming conversations. Hides the "Send private
#   message" links in cells/views that gate on Decidim::User#accepts_conversation?
#   (e.g. profile_minicard via UserPresenter#direct_messages_enabled?).
# - Forces UserPresenter#can_be_contacted? to false so that cells/views which
#   gate on it (profile_sidebar, author/contact, profile_actions_cell,
#   proposals admin show) hide their contact buttons.
# - Suppresses all ConversationMailer deliveries as a defense in depth in case a
#   conversation record is somehow created (e.g. via background jobs).
# Routes are also redirected at config/routes.rb.

module DisableMessaging
  module RejectAllConversations
    def accepts_conversation?(_user)
      false
    end
  end

  module ForbidContact
    def can_be_contacted?
      false
    end
  end

  module SuppressMailerDelivery
    def process(*)
      super
      message.perform_deliveries = false
    end
  end
end

Rails.application.config.to_prepare do
  Decidim::User.prepend(DisableMessaging::RejectAllConversations)
  Decidim::UserPresenter.prepend(DisableMessaging::ForbidContact)
  Decidim::Messaging::ConversationMailer.prepend(DisableMessaging::SuppressMailerDelivery)

  # decidim-admin moderation reports list the reportable's authors with an
  # unconditional "start conversation" link wrapping the user name. Since DM
  # is disabled, drop the anchor tag for User authors and just render the name.
  # Other branches (Meeting, Organization, fallback) are preserved verbatim.
  Decidim::Admin::Moderations::ReportsHelper.module_eval do
    def reportable_author_name(reportable)
      reportable_authors = reportable.try(:authors) || [reportable.try(:normalized_author)]
      content_tag :ul, class: "reportable-authors" do
        reportable_authors.select(&:present?).map do |author| # rubocop:disable Rails/CompactBlank
          case author
          when Decidim::User
            content_tag(:li, author.name)
          when Decidim::Meetings::Meeting
            content_tag :li do
              link_to resource_locator(author).path, target: "_blank", rel: "noopener" do
                decidim_sanitize_translated(author.title)
              end
            end
          when Decidim::Organization
            content_tag :li, organization_name(author)
          else # rubocop:disable Lint/DuplicateBranch
            content_tag(:li, author.name)
          end
        end.join.html_safe
      end
    end
  end
end

# frozen_string_literal: true

# Disable the Decidim direct messaging (conversations) feature.
# - Makes every user reject incoming conversations. Hides the "Send private
#   message" links in cells/views that gate on Decidim::User#accepts_conversation?
#   (e.g. profile_minicard via UserPresenter#direct_messages_enabled?).
# - Forces UserPresenter#can_be_contacted? to false so that cells/views which
#   gate on it (author/contact, profile_actions_cell, proposals admin show)
#   hide their contact buttons.
# - Suppresses all ConversationMailer deliveries as a defense in depth in case a
#   conversation record is somehow created (e.g. via background jobs).
# - Forces the Open Data users export column direct_messages_enabled to false
#   (it bypasses #accepts_conversation? and reads the raw user attribute).
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

  # The Open Data users export derives this column directly from the
  # +direct_message_types+ user attribute, bypassing #accepts_conversation?.
  # Force it to false so the public dataset never advertises DM availability.
  # The key is kept (not removed) to preserve the Open Data schema/columns.
  module ForceOpenDataDirectMessagesDisabled
    def serialize
      super.merge(direct_messages_enabled: false)
    end
  end

  # Hides the "Conversations" tab (DM feature) from user group profile pages.
  # NOTE: This can be removed if/when Decidim drops UserGroup
  module HideGroupConversationsTab
    def group_tabs
      items = [:members].tap do |keys|
        keys.append(:badges, :followers)
      end
      items.map { |key| tab_item(key) }
    end
  end
end

Rails.application.config.to_prepare do
  Decidim::User.prepend(DisableMessaging::RejectAllConversations)
  Decidim::UserPresenter.prepend(DisableMessaging::ForbidContact)
  Decidim::Messaging::ConversationMailer.prepend(DisableMessaging::SuppressMailerDelivery)
  Decidim::ProfileCell.prepend(DisableMessaging::HideGroupConversationsTab)
  Decidim::Exporters::OpenDataUserSerializer.prepend(DisableMessaging::ForceOpenDataDirectMessagesDisabled)

  # decidim-admin moderation reports list the reportable's authors with an
  # unconditional "start conversation" link wrapping the user name. Since DM
  # is disabled, drop the anchor tag for User authors and just render the name.
  # Other branches (Meeting, Organization, fallback) are preserved verbatim.
  Decidim::Admin::Moderations::ReportsHelper.module_eval do
    def reportable_author_name(reportable)
      reportable_authors = reportable.try(:authors) || [reportable.try(:normalized_author)]
      content_tag :ul, class: "reportable-authors" do
        reportable_authors.compact_blank.map do |author|
          case author
          when Decidim::User
            content_tag(:li, author.presenter.name)
          when Decidim::Meetings::Meeting
            content_tag :li do
              link_to resource_locator(author).path, target: "_blank", rel: "noopener" do
                decidim_sanitize_translated(author.title)
              end
            end
          when Decidim::Organization
            content_tag :li, organization_name(author)
          else
            content_tag(:li, author.name)
          end
        end.join.html_safe
      end
    end
  end
end

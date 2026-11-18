# frozen_string_literal: true

# Same as decidim/decidim#18010 (backport of decidim/decidim#17969 to 0.32)
Rails.application.config.to_prepare do
  Decidim::NeedsOrganization
  Decidim::Comments::Comment
  Decidim::Comments::CommentsController
  Decidim::Comments::VotesController
  Decidim::AmendmentsController
  Decidim::Proposals::InviteCoauthorsController

  module DecidimNeedsOrganizationScopePatch
    private

    def in_organization?(resource)
      return false if resource.blank?

      resource.organization == current_organization
    end

    def ensure_in_organization!(resource)
      return if resource.blank? || in_organization?(resource)

      raise ActiveRecord::RecordNotFound
    end
  end

  module DecidimCommentOrganizationScopePatch
    def for_organization(organization:)
      spaces = organization.participatory_spaces
      where(participatory_space: spaces).or(where(root_commentable: spaces))
    end
  end

  module DecidimCommentsControllerOrganizationScopePatch
    private

    def set_commentable
      @commentable ||= if commentable_gid
                         resource = GlobalID::Locator.locate_signed(commentable_gid)
                         ensure_in_organization!(resource)
                         resource
                       elsif comment
                         comment.root_commentable
                       end
    end

    def set_comment
      @comment = Decidim::Comments::Comment
                 .for_organization(organization: current_organization)
                 .find(params.expect(:id))
    end
  end

  module DecidimCommentVotesControllerOrganizationScopePatch
    private

    def set_comment
      @comment = Decidim::Comments::Comment
                 .for_organization(organization: current_organization)
                 .find(params.expect(:comment_id))
    end
  end

  module DecidimAmendmentsControllerOrganizationScopePatch
    def new
      raise ActionController::RoutingError, "Not Found" unless amendable

      enforce_permission_to :create, :amendment, current_component: amendable.component

      amendment_draft = amendable.amendments.find_by(amender: current_user.id, state: "draft")

      if amendment_draft
        redirect_to edit_draft_amend_path(amendment_draft)
      else
        @form = form(Decidim::Amendable::CreateForm).from_params(create_params)
      end
    end

    def create
      enforce_permission_to :create, :amendment, current_component: amendable.component

      @form = form(Decidim::Amendable::CreateForm).from_params(create_params)

      Decidim::Amendable::CreateDraft.call(@form) do
        on(:ok) do |amendment|
          flash[:notice] = t("created.success", scope: "decidim.amendments")
          redirect_to preview_draft_amend_path(amendment)
        end

        on(:invalid) do
          flash.now[:alert] = t("created.error", scope: "decidim.amendments")
          render :new, status: :unprocessable_content
        end
      end
    end

    def review
      enforce_permission_to :accept, :amendment, amendable:, current_component: amendable.component

      @form = form(Decidim::Amendable::ReviewForm).from_params(review_params)
    end

    def accept
      enforce_permission_to :accept, :amendment, amendable:, current_component: amendable.component

      @form = form(Decidim::Amendable::ReviewForm).from_params(review_params)

      Decidim::Amendable::Accept.call(@form) do
        on(:ok) do |emendation|
          flash[:notice] = t("accepted.success", scope: "decidim.amendments")
          redirect_to Decidim::ResourceLocatorPresenter.new(emendation).path
        end

        on(:invalid) do
          flash.now[:alert] = t("accepted.error", scope: "decidim.amendments")
          render :review, status: :unprocessable_content
        end
      end
    end

    private

    # Binds the create form to the already-checked amendable, so a conflicting
    # nested `amendment[amendable_gid]` cannot select another resource.
    def create_params
      params.deep_merge(amendment: { amendable_gid: amendable&.to_sgid&.to_s })
    end

    # Binds the review form to the amendment from the route, so a nested
    # `amendment[id]` cannot select a different amendment.
    def review_params
      params.deep_merge(amendment: { id: amendment&.id })
    end

    def amendable
      @amendable ||= begin
        # Existing amendments must always resolve their own amendable, so a
        # foreign amendment cannot be authorized through a local
        # `amendable_gid` supplied alongside its id. The signed resource is
        # only used when creating an amendment.
        resource = if creating_amendment?
                     GlobalID::Locator.locate_signed(amendable_gid)
                   else
                     amendment&.amendable
                   end
        ensure_in_organization!(resource)
        resource
      end
    end

    def creating_amendment?
      %w(new create).include?(action_name)
    end
  end

  module DecidimInviteCoauthorsControllerOrganizationScopePatch
    private

    def coauthor
      @coauthor ||= current_organization.users.find(params[:id])
    end
  end

  Decidim::NeedsOrganization::InstanceMethods.prepend(DecidimNeedsOrganizationScopePatch)
  Decidim::Comments::Comment.singleton_class.prepend(DecidimCommentOrganizationScopePatch)
  Decidim::Comments::CommentsController.prepend(DecidimCommentsControllerOrganizationScopePatch)
  Decidim::Comments::VotesController.prepend(DecidimCommentVotesControllerOrganizationScopePatch)
  Decidim::AmendmentsController.prepend(DecidimAmendmentsControllerOrganizationScopePatch)
  Decidim::Proposals::InviteCoauthorsController.prepend(DecidimInviteCoauthorsControllerOrganizationScopePatch)
end

# frozen_string_literal: true

Rails.application.config.to_prepare do
  # Override Decidim::Orderable
  #
  # Use cookies to store default orders
  Decidim::Proposals::ProposalsController.prepend Decidim::Proposals::CookieOrderable

  # Decidim::Proposals::ProposalWizardCreateStepForm
  #
  # minimum title length should be 8
  Decidim::Proposals::ProposalWizardCreateStepForm.validators.each do |validator|
    if validator.class == ActiveModel::Validations::LengthValidator && # rubocop:disable Style/Next
       validator.attributes.include?(:title)

      fixed_options = validator.options.dup
      fixed_options[:minimum] = 8
      validator.instance_eval do
        @options = fixed_options.freeze
      end
    end
  end

  # Decidim::Proposals::Admin::ProposalForm
  #
  # minimum title length should be 8
  Decidim::Proposals::Admin::ProposalForm.validators.each do |validator|
    if validator.class == ActiveModel::Validations::LengthValidator && # rubocop:disable Style/Next
       validator.attributes.first.match?(/^title_/)

      fixed_options = validator.options.dup
      fixed_options[:minimum] = 8
      validator.instance_eval do
        @options = fixed_options.freeze
      end
    end
  end
end

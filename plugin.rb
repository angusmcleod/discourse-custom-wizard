# frozen_string_literal: true
# name: discourse-custom-wizard
# about: Create custom wizards
# version: 0.8.1
# authors: Angus McLeod
# url: https://github.com/paviliondev/discourse-custom-wizard
# contact emails: angus@thepavilion.io

## learning_unit
# unit:        custom_wizard:templates_and_builder
# type:        introduction
# title:       Adding a new wizard field attribute.
# description: In this unit, we'll learn about creating, editing, validating
#              and building wizard templates by adding a new field attribute.
##
gem 'liquid', '5.0.1', require: true
register_asset 'stylesheets/common/wizard-admin.scss'
register_asset 'stylesheets/common/wizard-mapper.scss'

enabled_site_setting :custom_wizard_enabled

config = Rails.application.config
plugin_asset_path = "#{Rails.root}/plugins/discourse-custom-wizard/assets"
config.assets.paths << "#{plugin_asset_path}/javascripts"
config.assets.paths << "#{plugin_asset_path}/stylesheets/wizard"

if Rails.env.production?
  config.assets.precompile += %w{
    wizard-custom-guest.js
    wizard-custom-globals.js
    wizard-custom.js
    wizard-custom-start.js
    wizard-plugin.js.erb
    wizard-raw-templates.js.erb
  }
end

if respond_to?(:register_svg_icon)
  register_svg_icon "far-calendar"
  register_svg_icon "chevron-right"
  register_svg_icon "chevron-left"
  register_svg_icon "save"
  register_svg_icon "arrow-right"
end

class ::Sprockets::DirectiveProcessor
  def process_require_tree_discourse_directive(path = ".")
    raise CustomWizard::SprocketsEmptyPath, "path cannot be empty" if path == "."

    discourse_asset_path = "#{Rails.root}/app/assets/javascripts/"
    path = File.expand_path(path, discourse_asset_path)
    stat = @environment.stat(path)

    if stat && stat.directory?
      require_paths(*@environment.stat_sorted_tree_with_dependencies(path))
    else
      raise CustomWizard::SprocketsFileNotFound, "#{path} not found in discourse core"
    end
  end
end

after_initialize do
  %w[
    ../lib/custom_wizard/engine.rb
    ../config/routes.rb
    ../controllers/custom_wizard/admin/admin.rb
    ../controllers/custom_wizard/admin/wizard.rb
    ../controllers/custom_wizard/admin/submissions.rb
    ../controllers/custom_wizard/admin/api.rb
    ../controllers/custom_wizard/admin/logs.rb
    ../controllers/custom_wizard/admin/manager.rb
    ../controllers/custom_wizard/admin/custom_fields.rb
    ../controllers/custom_wizard/wizard.rb
    ../controllers/custom_wizard/steps.rb
    ../controllers/custom_wizard/realtime_validations.rb
    ../jobs/refresh_api_access_token.rb
    ../jobs/set_after_time_wizard.rb
    ../lib/custom_wizard/validators/template.rb
    ../lib/custom_wizard/validators/update.rb
    ../lib/custom_wizard/action_result.rb
    ../lib/custom_wizard/action.rb
    ../lib/custom_wizard/builder.rb
    ../lib/custom_wizard/cache.rb
    ../lib/custom_wizard/custom_field.rb
    ../lib/custom_wizard/field.rb
    ../lib/custom_wizard/realtime_validation.rb
    ../lib/custom_wizard/realtime_validations/result.rb
    ../lib/custom_wizard/realtime_validations/similar_topics.rb
    ../lib/custom_wizard/mapper.rb
    ../lib/custom_wizard/log.rb
    ../lib/custom_wizard/step_updater.rb
    ../lib/custom_wizard/step.rb
    ../lib/custom_wizard/submission.rb
    ../lib/custom_wizard/template.rb
    ../lib/custom_wizard/wizard.rb
    ../lib/custom_wizard/api/api.rb
    ../lib/custom_wizard/api/authorization.rb
    ../lib/custom_wizard/api/endpoint.rb
    ../lib/custom_wizard/api/log_entry.rb
    ../lib/custom_wizard/liquid_extensions/first_non_empty.rb
    ../lib/custom_wizard/exceptions/exceptions.rb
    ../serializers/custom_wizard/api/authorization_serializer.rb
    ../serializers/custom_wizard/api/basic_endpoint_serializer.rb
    ../serializers/custom_wizard/api/endpoint_serializer.rb
    ../serializers/custom_wizard/api/log_serializer.rb
    ../serializers/custom_wizard/api_serializer.rb
    ../serializers/custom_wizard/basic_api_serializer.rb
    ../serializers/custom_wizard/basic_wizard_serializer.rb
    ../serializers/custom_wizard/custom_field_serializer.rb
    ../serializers/custom_wizard/wizard_field_serializer.rb
    ../serializers/custom_wizard/wizard_step_serializer.rb
    ../serializers/custom_wizard/wizard_serializer.rb
    ../serializers/custom_wizard/log_serializer.rb
    ../serializers/custom_wizard/submission_serializer.rb
    ../serializers/custom_wizard/realtime_validation/similar_topics_serializer.rb
    ../extensions/extra_locales_controller.rb
    ../extensions/invites_controller.rb
    ../extensions/users_controller.rb
    ../extensions/custom_field/preloader.rb
    ../extensions/custom_field/serializer.rb
    ../extensions/custom_field/extension.rb
  ].each do |path|
    load File.expand_path(path, __FILE__)
  end

  Liquid::Template.register_filter(::CustomWizard::LiquidFilter::FirstNonEmpty)

  add_class_method(:wizard, :user_requires_completion?) do |user|
    wizard_result = self.new(user).requires_completion?
    return wizard_result if wizard_result

    custom_redirect = false

    if user &&
       user.first_seen_at.blank? &&
       wizard = CustomWizard::Wizard.after_signup(user)

      if !wizard.completed?
        custom_redirect = true
        CustomWizard::Wizard.set_user_redirect(wizard.id, user)
      end
    end

    !!custom_redirect
  end

  add_to_class(:users_controller, :wizard_path) do
    if custom_wizard_redirect = current_user.custom_fields['redirect_to_wizard']
      "#{Discourse.base_url}/w/#{custom_wizard_redirect.dasherize}"
    else
      "#{Discourse.base_url}/wizard"
    end
  end

  add_to_serializer(:current_user, :redirect_to_wizard) do
    object.custom_fields['redirect_to_wizard']
  end

  on(:user_approved) do |user|
    if wizard = CustomWizard::Wizard.after_signup(user)
      CustomWizard::Wizard.set_user_redirect(wizard.id, user)
    end
  end

  add_to_class(:application_controller, :redirect_to_wizard_if_required) do
    wizard_id = current_user.custom_fields['redirect_to_wizard']
    @excluded_routes ||= SiteSetting.wizard_redirect_exclude_paths.split('|') + ['/w/']
    url = request.referer || request.original_url

    if request.format === 'text/html' && !@excluded_routes.any? { |str| /#{str}/ =~ url } && wizard_id
      if request.referer !~ /\/w\// && request.referer !~ /\/invites\//
        CustomWizard::Wizard.set_wizard_redirect(current_user, wizard_id, request.referer)
      end
      if CustomWizard::Template.exists?(wizard_id)
        redirect_to "/w/#{wizard_id.dasherize}"
      end
    end
  end

  add_to_serializer(:site, :include_wizard_required?) do
    scope.is_admin? && Wizard.new(scope.user).requires_completion?
  end

  add_to_serializer(:site, :complete_custom_wizard) do
    if scope.user && requires_completion = CustomWizard::Wizard.prompt_completion(scope.user)
      requires_completion.map { |w| { name: w[:name], url: "/w/#{w[:id]}" } }
    end
  end

  add_to_serializer(:site, :include_complete_custom_wizard?) do
    complete_custom_wizard.present?
  end

  add_model_callback(:application_controller, :before_action) do
    redirect_to_wizard_if_required if current_user
  end

  ::ExtraLocalesController.prepend ExtraLocalesControllerCustomWizard
  ::InvitesController.prepend InvitesControllerCustomWizard
  ::UsersController.prepend CustomWizardUsersController

  full_path = "#{Rails.root}/plugins/discourse-custom-wizard/assets/stylesheets/wizard/wizard_custom.scss"
  if Stylesheet::Importer.respond_to?(:plugin_assets)
    Stylesheet::Importer.plugin_assets['wizard_custom'] = Set[full_path]
  else
    # legacy method, Discourse 2.7.0.beta5 and below
    DiscoursePluginRegistry.register_asset(full_path, {}, "wizard_custom")
    Stylesheet::Importer.register_import("wizard_custom") do
      import_files(DiscoursePluginRegistry.stylesheets["wizard_custom"])
    end
  end

  CustomWizard::CustomField::CLASSES.keys.each do |klass|
    class_constant = klass.to_s.classify.constantize

    add_model_callback(klass, :after_initialize) do
      if CustomWizard::CustomField.enabled?
        CustomWizard::CustomField.list_by(:klass, klass.to_s).each do |field|
          class_constant.register_custom_field_type(field[:name], field[:type].to_sym)
        end
      end
    end

    class_constant.singleton_class.prepend CustomWizardCustomFieldPreloader
    class_constant.singleton_class.prepend CustomWizardCustomFieldExtension
  end

  CustomWizard::CustomField.serializers.each do |serializer_klass|
    "#{serializer_klass}_serializer".classify.constantize.prepend CustomWizardCustomFieldSerializer
  end

  DiscourseEvent.trigger(:custom_wizard_ready)
end

# frozen_string_literal: true
class CustomWizard::TemplateValidator
  include HasErrors
  include ActiveModel::Model

  def initialize(data, opts = {})
    @data = data
    @opts = opts
  end

  ##
  # type:        step
  # number:      5
  # title:       Add a template validation (optional)
  # description: If our new attribute requires validation of a value entered
  #              during administration of a wizard that should be handled here.
  #              Template validators are run before the template is saved to
  #              the database.
  ##
  def perform
    data = @data

    check_id(data, :wizard)
    check_required(data, :wizard)
    validate_after_time

    data[:steps].each do |step|
      check_required(step, :step)

      if data[:fields].present?
        data[:fields].each do |field|
          check_required(field, :field)
        end
      end
    end

    if data[:actions].present?
      data[:actions].each do |action|
        check_required(action, :action)
      end
    end

    if errors.any?
      false
    else
      true
    end
  end

  def self.required
    {
      wizard: ['id', 'name', 'steps'],
      step: ['id'],
      field: ['id', 'type'],
      action: ['id', 'type']
    }
  end

  private

  def check_required(object, type)
    CustomWizard::TemplateValidator.required[type].each do |property|
      if object[property].blank?
        errors.add :base, I18n.t("wizard.validation.required", property: property)
      end
    end
  end

  def check_id(object, type)
    if type === :wizard && @opts[:create] && CustomWizard::Template.exists?(object[:id])
      errors.add :base, I18n.t("wizard.validation.conflict", wizard_id: object[:id])
    end
  end

  def validate_after_time
    return unless @data[:after_time]

    wizard = CustomWizard::Wizard.create(@data[:id]) if !@opts[:create]
    current_time = wizard.present? ? wizard.after_time_scheduled : nil
    new_time = @data[:after_time_scheduled]

    begin
      active_time = Time.parse(new_time.present? ? new_time : current_time).utc
    rescue ArgumentError
      invalid_time = true
    end

    if invalid_time || active_time.blank? || active_time < Time.now.utc
      errors.add :base, I18n.t("wizard.validation.after_time")
    end
  end
end

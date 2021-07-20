# frozen_string_literal: true

class CustomWizard::FieldSerializer < ::ApplicationSerializer

  attributes *CustomWizard::Field.serializable_attributes

  def id
    object.id
  end

  def index
    object.index
  end

  def type
    object.type
  end

  def required
    object.required
  end

  def value
    object.value
  end

  def i18n_key
    @i18n_key ||= "wizard.step.#{object.step.id}.fields.#{object.id}".underscore
  end

  def label
    return object.label if object.label.present?
    I18n.t("#{object.key || i18n_key}.label", default: '')
  end

  def include_label?
    label.present?
  end

  def description
    return object.description if object.description.present?
    I18n.t("#{object.key || i18n_key}.description", default: '', base_url: Discourse.base_url)
  end

  def include_description?
    description.present?
  end

  def image
    object.image
  end

  def include_image?
    object.image.present?
  end

  def placeholder
    return object.placeholder if object.placeholder.present?
    I18n.t("#{object.key || i18n_key}.placeholder", default: '')
  end

  def include_placeholder?
    placeholder.present?
  end

  def file_types
    object.file_types
  end

  def format
    object.format
  end

  def limit
    object.limit
  end

  def property
    object.property
  end

  def content
    object.content
  end

  def validations
    validations = {}
    object.validations&.each do |type, props|
      next unless props["status"]
      validations[props["position"]] ||= {}
      validations[props["position"]][type] = props.merge CustomWizard::RealtimeValidation.types[type.to_sym]
    end

    validations
  end

  def max_length
    object.max_length
  end

  def char_counter
    object.char_counter
  end

  def preview_template
    object.preview_template
  end
end

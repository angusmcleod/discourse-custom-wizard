# frozen_string_literal: true

class CustomWizard::Step
  include ActiveModel::SerializerSupport

  def self.attribute_map
    {
      id: [:serializable, :permitted],
      updater: [],
      index: [:accessible, :serializable, :permitted],
      title: [:accessible, :serializable, :permitted],
      description: [:accessible, :serializable],
      key: [:accessible, :permitted],
      permitted: [:accessible, :serializable],
      permitted_message: [:accessible, :serializable],
      fields: [:accessible],
      next: [:accessible, :serializable],
      previous: [:accessible, :serializable],
      banner: [:accessible, :serializable, :permitted],
      disabled: [:accessible],
      description_vars: [:accessible],
      last_step: [:accessible],
      force_final: [:accessible],
      conditional_final_step: [:accessible],
      wizard: [:accessible],
      raw_description: [:permitted],
      required_data_message: [:permitted],
      required_data: [:permitted, :mapped],
      permitted_params: [:permitted, :mapped],
      condition: [:permitted, :mapped],
      final: [:serializable]
    }
  end

  def self.type_attributes(type)
    attribute_map.map { |attribute, props| props.include?(type.to_sym) ? attribute : nil }.compact
  end

  def self.all_attributes
    attribute_map.keys
  end

  def self.accessible_attributes
    type_attributes(:accessible)
  end

  def self.included_attributes
    all_attributes - excluded_attributes
  end

  def self.readonly_attributes
    included_attributes - accessible_attributes
  end

  def self.excluded_attributes
    type_attributes(:excluded)
  end

  attr_reader *readonly_attributes
  attr_accessor *accessible_attributes

  def initialize(id)
    @id = id
    @fields = []
  end

  def add_field(attrs)
    field = ::CustomWizard::Field.new(attrs)
    field.index = (@fields.size == 1 ? 0 : @fields.size) if field.index.nil?
    field.step = self
    @fields << field
    field
  end

  def has_fields?
    @fields.present?
  end

  def on_update(&block)
    @updater = block
  end

  def update_field_order!
    @fields.sort_by!(&:index)
  end

  def final?
    return true if force_final && conditional_final_step
    return true if last_step
    false
  end
end

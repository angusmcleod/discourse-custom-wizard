# frozen_string_literal: true
class CustomWizard::Field
  def self.types
    @types ||= {
      text: {
        min_length: nil,
        max_length: nil,
        prefill: nil,
        char_counter: nil,
        validations: nil
      },
      textarea: {
        min_length: nil,
        max_length: nil,
        prefill: nil,
        char_counter: nil
      },
      composer: {
        min_length: nil,
        max_length: nil,
        char_counter: nil
      },
      text_only: {},
      date: {
        format: "YYYY-MM-DD"
      },
      time: {
        format: "HH:mm"
      },
      date_time: {
        format: ""
      },
      number: {},
      checkbox: {},
      url: {
        min_length: nil
      },
      upload: {
        file_types: '.jpg,.jpeg,.png'
      },
      dropdown: {
        prefill: nil,
        content: nil
      },
      tag: {
        limit: nil,
        prefill: nil,
        content: nil
      },
      category: {
        limit: 1,
        property: 'id',
        prefill: nil,
        content: nil
      },
      group: {
        prefill: nil,
        content: nil
      },
      user_selector: {}
    }
  end

  def self.require_assets
    @require_assets ||= {}
  end

  def self.register(type, plugin = nil, asset_paths = [], opts = {})
    if type
      types[type.to_sym] ||= {}
      types[type.to_sym] = opts[:type_opts] if opts[:type_opts].present?
    end

    if plugin && asset_paths
      require_assets[plugin] = asset_paths
    end
  end
end

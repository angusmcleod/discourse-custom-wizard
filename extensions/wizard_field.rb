# frozen_string_literal: true
module CustomWizardFieldExtension
  attr_reader :raw,
              :label,
              :description,
              :image,
              :key,
              :validations,
              :min_length,
              :max_length,
              :char_counter,
              :file_types,
              :format,
              :limit,
              :property,
              :content,
              :number

  def initialize(attrs)
    super
    @raw = attrs || {}
    @description = attrs[:description]
    @image = attrs[:image]
    @key = attrs[:key]
    @validations = attrs[:validations]
    @min_length = attrs[:min_length]
    @max_length = attrs[:max_length]
    @char_counter = attrs[:char_counter]
    @file_types = attrs[:file_types]
    @format = attrs[:format]
    @limit = attrs[:limit]
    @property = attrs[:property]
    @content = attrs[:content]
    @number = attrs[:number]
  end

  def label
    @label ||= PrettyText.cook(@raw[:label])
  end
end

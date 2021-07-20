# frozen_string_literal: true
class CustomWizard::Builder
  attr_accessor :wizard, :updater, :template

  def initialize(wizard_id, user = nil)
    @template = CustomWizard::Template.create(wizard_id)
    return nil if @template.nil?
    @wizard = CustomWizard::Wizard.new(template.data, user)
  end

  def self.sorted_handlers
    @sorted_handlers ||= []
  end

  def self.step_handlers
    sorted_handlers.map { |h| { wizard_id: h[:wizard_id], block: h[:block] } }
  end

  def self.add_step_handler(priority = 0, wizard_id, &block)
    sorted_handlers << { priority: priority, wizard_id: wizard_id, block: block }
    @sorted_handlers.sort_by! { |h| -h[:priority] }
  end

  def mapper
    CustomWizard::Mapper.new(
      user: @wizard.user,
      data: @wizard.current_submission&.fields_and_meta
    )
  end

  def build(build_opts = {}, params = {})
    return nil if !SiteSetting.custom_wizard_enabled || !@wizard
    return @wizard if !@wizard.can_access? && !build_opts[:force]

    build_opts[:reset] = build_opts[:reset] || @wizard.restart_on_revisit

    @template.steps.each do |step_template|
      next if !check_condition(step_template)

      @wizard.append_step(step_template['id']) do |step|
        step = check_if_permitted(step, step_template)
        next if !step.permitted

        save_permitted_params(step_template, params)
        step = add_step_attributes(step, step_template)
        step = append_step_fields(step, step_template, build_opts)

        step.on_update do |updater|
          @updater = updater
          @submission = @wizard.current_submission
          @submission.fields.merge!(@updater.submission)

          @updater.validate
          next if @updater.errors.any?

          apply_step_handlers
          next if @updater.errors.any?

          run_step_actions

          if @updater.errors.empty?
            route_to = @submission.route_to
            @submission.route_to = nil
            @submission.save

            @wizard.update!
            @updater.result[:redirect_on_next] = route_to if route_to

            true
          else
            false
          end
        end
      end
    end

    @wizard.update!
    @wizard
  end

  ##
  # type:        step
  # number:      7
  # title:       Add it to the builder
  # description: When our template is built into a wizard, we need our new
  #              attribute to be built here in the builder so it's ready to
  #              be sent to the wizard client.
  ##
  def append_field(step, step_template, field_template, build_opts)
    params = {
      id: field_template['id'],
      type: field_template['type'],
      required: field_template['required']
    }

    %w(label description image key validations min_length max_length char_counter).each do |key|
      params[key.to_sym] = field_template[key] if field_template[key]
    end

    params[:value] = prefill_field(field_template, step_template)

    if !build_opts[:reset] && (submission = @wizard.current_submission).present?
      params[:value] = submission.fields[field_template['id']] if submission.fields[field_template['id']]
    end

    if field_template['type'] === 'group' && params[:value].present?
      params[:value] = params[:value].first
    end

    if field_template['type'] === 'checkbox'
      params[:value] = standardise_boolean(params[:value])
    end

    if field_template['type'] === 'upload'
      params[:file_types] = field_template['file_types']
    end

    if ['date', 'time', 'date_time'].include?(field_template['type'])
      params[:format] = field_template['format']
    end

    if field_template['type'] === 'category' || field_template['type'] === 'tag'
      params[:limit] = field_template['limit']
    end

    if field_template['type'] === 'category'
      params[:property] = field_template['property']
    end

    if field_template['type'] === 'category' || (
          field_template['validations'] &&
          field_template['validations']['similar_topics'] &&
          field_template['validations']['similar_topics']['categories'].present?
        )
      @wizard.needs_categories = true
    end

    if field_template['type'] === 'group'
      @wizard.needs_groups = true
    end

    if (content_inputs = field_template['content']).present?
      content = CustomWizard::Mapper.new(
        inputs: content_inputs,
        user: @wizard.user,
        data: @wizard.current_submission&.fields_and_meta,
        opts: {
          with_type: true
        }
      ).perform

      if content.present? &&
         content[:result].present?

        if content[:type] == 'association'
          content[:result] = content[:result].map do |item|
            {
              id: item[:key],
              name: item[:value]
            }
          end
        end

        if content[:type] == 'assignment' && field_template['type'] === 'dropdown'
          content[:result] = content[:result].map do |item|
            {
              id: item,
              name: item
            }
          end
        end

        params[:content] = content[:result]
      end
    end

    if field_template['index'].present?
      index = CustomWizard::Mapper.new(
        inputs: field_template['index'],
        user: @wizard.user,
        data: @wizard.current_submission&.fields_and_meta
      ).perform

      params[:index] = index.to_i unless index.nil?
    end

    if field_template['description'].present?
      params[:description] = mapper.interpolate(
        field_template['description'],
        user: true,
        value: true,
        wizard: true,
        template: true
      )
    end

    if field_template['preview_template'].present?
      preview_template = mapper.interpolate(
        field_template['preview_template'],
        user: true,
        value: true,
        wizard: true,
        template: true
      )

      params[:preview_template] = PrettyText.cook(preview_template)
    end

    if field_template['placeholder'].present?
      params[:placeholder] = mapper.interpolate(
        field_template['placeholder'],
        user: true,
        value: true,
        wizard: true,
        template: true
      )
    end

    field = step.add_field(params)
  end

  def prefill_field(field_template, step_template)
    if (prefill = field_template['prefill']).present?
      CustomWizard::Mapper.new(
        inputs: prefill,
        user: @wizard.user,
        data: @wizard.current_submission&.fields_and_meta
      ).perform
    end
  end

  def check_condition(template)
    if template['condition'].present?
      result = CustomWizard::Mapper.new(
        inputs: template['condition'],
        user: @wizard.user,
        data: @wizard.current_submission&.fields_and_meta,
        opts: {
          multiple: true
        }
      ).perform

      result.any?
    else
      true
    end
  end

  def check_if_permitted(step, step_template)
    step.permitted = true

    if step_template['required_data']
      step = ensure_required_data(step, step_template)
    end

    if !step.permitted
      if step_template['required_data_message']
        step.permitted_message = step_template['required_data_message']
      end
    end

    step
  end

  def add_step_attributes(step, step_template)
    %w(index title banner key force_final).each do |attr|
      step.send("#{attr}=", step_template[attr]) if step_template[attr]
    end

    if step_template['description']
      step.description = mapper.interpolate(
        step_template['description'],
        user: true,
        value: true,
        wizard: true,
        template: true
      )
      step.description = PrettyText.cook(step.description)
    end

    step
  end

  def append_step_fields(step, step_template, build_opts)
    if step_template['fields'] && step_template['fields'].length
      step_template['fields'].each do |field_template|
        next if !check_condition(field_template)
        append_field(step, step_template, field_template, build_opts)
      end
    end

    step.update_field_order!
    step
  end

  def standardise_boolean(value)
    ActiveRecord::Type::Boolean.new.cast(value)
  end

  def save_permitted_params(step_template, params)
    return unless step_template['permitted_params'].present?

    permitted_params = step_template['permitted_params']
    permitted_data = {}
    submission_key = nil
    params_key = nil
    submission = @wizard.current_submission

    permitted_params.each do |pp|
      pair = pp['pairs'].first
      params_key = pair['key'].to_sym
      submission_key = pair['value'].to_sym

      if submission_key && params_key && params[params_key].present?
        submission.permitted_param_keys << submission_key.to_s
        submission.fields[submission_key] = params[params_key]
      end
    end

    submission.save
  end

  def ensure_required_data(step, step_template)
    step_template['required_data'].each do |required|
      pairs = required['pairs'].select do |pair|
        pair['key'].present? && pair['value'].present?
      end

      if pairs.any? && !@wizard.current_submission.present?
        step.permitted = false
        break
      end

      pairs.each do |pair|
        pair['key'] = @wizard.current_submission.fields[pair['key']]
      end

      if !mapper.validate_pairs(pairs)
        step.permitted = false
        break
      end
    end

    step
  end

  def apply_step_handlers
    CustomWizard::Builder.step_handlers.each do |handler|
      if handler[:wizard_id] == @wizard.id
        handler[:block].call(self)
      end
    end
  end

  def run_step_actions
    if @template.actions.present?
      @template.actions.each do |action_template|
        if action_template['run_after'] === updater.step.id
          result = CustomWizard::Action.new(
            action: action_template,
            wizard: @wizard,
            submission: @submission
          ).perform

          if result.success?
            @submission = result.submission
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

describe CustomWizard::RealtimeValidationsController do

  fab!(:validation_type) { "test_stub" }
  fab!(:validation_type_stub) {
    {
      types: [:text],
      component: "similar-topics-validator",
      backend: true,
      required_params: []
    }
  }

  before(:all) do
    sign_in(Fabricate(:user))
    CustomWizard::RealtimeValidation.types = { test_stub: validation_type_stub }

    class CustomWizard::RealtimeValidation::TestStub
      attr_accessor :user

      def initialize(user)
        @user = user
      end

      def perform(params)
        result = CustomWizard::RealtimeValidation::Result.new(:test_stub)
        result.items = ["hello", "world"]
        result
      end
    end

    class ::CustomWizard::RealtimeValidation::TestStubSerializer < ApplicationSerializer
      attributes :item

      def item
        object
      end
    end
  end

  it "gives the correct response for a given type" do
    get '/realtime-validations.json', params: { type: validation_type }

    expect(response.status).to eq(200)
    expected_response = [
      { "item" => "hello" },
      { "item" => "world" }
    ]
    expect(JSON.parse(response.body)).to eq(expected_response)
  end

  it "gives 400 error when no type is passed" do
    get '/realtime-validations.json'

    expect(response.status).to eq(400)
  end

  it "gives 500 response code when a non existant type is passed" do
    get '/realtime-validations.json', params: { type: "random_type" }

    expect(response.status).to eq(500)
  end
end

# frozen_string_literal: true

require "test_helper"
class ModelsTest < ActiveSupport::TestCase
  def test_models_namespace_is_defined
    assert defined?(Ksef::Models)
    assert_kind_of Module, Ksef::Models
  end
end

# frozen_string_literal: true

require 'test_helper'

class VersionTest < Minitest::Test
  def test_version_is_defined
    refute_nil OrchestraAI::VERSION
  end

  def test_version_is_a_string
    assert_instance_of String, OrchestraAI::VERSION
  end

  def test_version_follows_semver
    assert_match(/\A\d+\.\d+\.\d+/, OrchestraAI::VERSION)
  end
end

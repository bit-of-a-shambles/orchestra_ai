# frozen_string_literal: true

require 'test_helper'

class GemspecTest < Minitest::Test
  def setup
    @gemspec_path = File.expand_path('../../orchestra_ai.gemspec', __dir__)
    @gemspec = Gem::Specification.load(@gemspec_path)
  end

  def test_gemspec_is_valid
    assert @gemspec, 'Gemspec should load without errors'
    assert_equal 'orchestra_ai', @gemspec.name
  end

  def test_executable_is_declared
    assert_includes @gemspec.executables, 'orchestra',
                    'Gemspec should declare orchestra as an executable'
  end

  def test_bindir_is_exe
    assert_equal 'exe', @gemspec.bindir,
                 'Gemspec bindir should be exe (not bin) for proper gem installation'
  end

  def test_executable_file_exists
    executable_path = File.join(File.dirname(@gemspec_path), @gemspec.bindir, 'orchestra')
    assert File.exist?(executable_path),
           "Executable should exist at #{executable_path}"
  end

  def test_executable_is_included_in_files
    # The exe/ directory should NOT be excluded from files
    exe_files = @gemspec.files.select { |f| f.start_with?('exe/') }
    assert_includes exe_files, 'exe/orchestra',
                    'exe/orchestra should be included in gem files'
  end

  def test_bin_directory_is_excluded_from_files
    # bin/ is for development scripts, should be excluded
    bin_files = @gemspec.files.select { |f| f.start_with?('bin/') }
    assert_empty bin_files,
                 'bin/ directory should be excluded from gem files (development only)'
  end

  def test_executable_does_not_require_bundler_setup
    executable_path = File.join(File.dirname(@gemspec_path), @gemspec.bindir, 'orchestra')
    content = File.read(executable_path)

    refute_match(%r{require.*bundler/setup}, content,
                 'Executable should not require bundler/setup (breaks gem installation)')
  end

  def test_executable_requires_orchestra_ai
    executable_path = File.join(File.dirname(@gemspec_path), @gemspec.bindir, 'orchestra')
    content = File.read(executable_path)

    assert_match(/require.*orchestra_ai/, content,
                 'Executable should require orchestra_ai')
  end

  def test_executable_requires_thor
    executable_path = File.join(File.dirname(@gemspec_path), @gemspec.bindir, 'orchestra')
    content = File.read(executable_path)

    assert_match(/require.*thor/, content,
                 'Executable should require thor for CLI')
  end

  def test_executable_has_shebang
    executable_path = File.join(File.dirname(@gemspec_path), @gemspec.bindir, 'orchestra')
    first_line = File.open(executable_path, &:readline)

    assert_match(/^#!.*ruby/, first_line,
                 'Executable should have ruby shebang')
  end

  def test_thor_is_runtime_dependency
    thor_dep = @gemspec.dependencies.find { |d| d.name == 'thor' }
    assert thor_dep, 'Thor should be a dependency'
    assert_equal :runtime, thor_dep.type,
                 'Thor should be a runtime dependency (not development)'
  end

  def test_all_required_runtime_dependencies
    runtime_deps = @gemspec.runtime_dependencies.map(&:name)

    assert_includes runtime_deps, 'thor', 'Missing runtime dependency: thor'
    assert_includes runtime_deps, 'ruby_llm', 'Missing runtime dependency: ruby_llm'
    assert_includes runtime_deps, 'concurrent-ruby', 'Missing runtime dependency: concurrent-ruby'
    assert_includes runtime_deps, 'zeitwerk', 'Missing runtime dependency: zeitwerk'
  end
end

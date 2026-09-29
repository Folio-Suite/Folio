#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'fileutils'
require 'tmpdir'
require_relative '../check-standalone-app'

class StandaloneAppCheckTest < Minitest::Test
  def test_parses_dependencies_with_spaces_and_both_architectures
    output = <<~TEXT
      /tmp/My Folio.app/Contents/MacOS/Write (architecture arm64):
          @rpath/FolioKit.framework/Versions/A/FolioKit (compatibility version 1.0.0, current version 1.0.0)
          /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit (compatibility version 45.0.0, current version 45.0.0)
      /tmp/My Folio.app/Contents/MacOS/Write (architecture x86_64):
          @rpath/FolioKit.framework/Versions/A/FolioKit (compatibility version 1.0.0, current version 1.0.0)
    TEXT
    assert_equal ['@rpath/FolioKit.framework/Versions/A/FolioKit',
                  '/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit'],
                 StandaloneAppCheck.dependencies(output)
  end

  def test_parses_runpaths_with_spaces_and_deduplicates_architectures
    output = <<~TEXT
      Load command 5
                cmd LC_RPATH
            cmdsize 96
               path /tmp/Build With Spaces/PackageFrameworks (offset 12)
      Load command 6
                cmd LC_RPATH
            cmdsize 48
               path @executable_path/../Frameworks (offset 12)
      Load command 5
                cmd LC_RPATH
            cmdsize 48
               path @executable_path/../Frameworks (offset 12)
    TEXT
    assert_equal ['/tmp/Build With Spaces/PackageFrameworks', '@executable_path/../Frameworks'],
                 StandaloneAppCheck.runpaths(output)
  end

  def test_absolute_developer_runpath_is_rejected
    check = StandaloneAppCheck.new('/tmp/Write.app', unsigned: true)
    def check.capture(*command)
      if command[1] == '-l'
        return "cmd LC_RPATH\ncmdsize 80\npath /tmp/Build With Spaces/PackageFrameworks (offset 12)\n" \
               "cmd LC_RPATH\ncmdsize 48\npath @executable_path/../Frameworks (offset 12)\n"
      end
      ''
    end
    error = assert_raises(RuntimeError) do
      check.verify_binary(__FILE__, required_runpath: '@executable_path/../Frameworks')
    end
    assert_match(/absolute non-system runpath/, error.message)
  end

  def test_dependency_requires_complete_embedded_framework_binary
    Dir.mktmpdir('folio standalone path with spaces ') do |directory|
      app = File.join(directory, 'Write.app')
      executable = File.join(app, 'Contents', 'MacOS', 'Write')
      framework = File.join(app, 'Contents', 'Frameworks', 'FolioKit.framework')
      FileUtils.mkdir_p(File.dirname(executable))
      FileUtils.mkdir_p(framework)
      check = StandaloneAppCheck.new(app, unsigned: true)
      dependency = '@rpath/FolioKit.framework/Versions/A/FolioKit'
      runpaths = ['@executable_path/../Frameworks']
      assert_raises(RuntimeError) { check.verify_dependency(dependency, executable, executable, runpaths) }
      FileUtils.mkdir_p(File.join(framework, 'Versions', 'A'))
      File.write(File.join(framework, 'Versions', 'A', 'FolioKit'), 'binary fixture')
      check.verify_dependency(dependency, executable, executable, runpaths)
    end
  end

  def test_relative_dependency_cannot_escape_app
    Dir.mktmpdir do |directory|
      app = File.join(directory, 'Write.app')
      executable = File.join(app, 'Contents', 'MacOS', 'Write')
      FileUtils.mkdir_p(File.dirname(executable))
      File.write(executable, 'binary fixture')
      outside = File.join(directory, 'Outside.dylib')
      File.write(outside, 'binary fixture')
      check = StandaloneAppCheck.new(app, unsigned: true)
      assert_raises(RuntimeError) do
        check.verify_dependency('@executable_path/../../../Outside.dylib', executable, executable, [])
      end
    end
  end

  def test_parent_symlink_does_not_break_app_containment
    Dir.mktmpdir do |directory|
      app = File.join(directory, 'Write.app')
      member = File.join(app, 'Contents', 'Frameworks', 'FolioKit.framework', 'Versions', 'A', 'FolioKit')
      FileUtils.mkdir_p(File.dirname(member))
      File.write(member, 'binary fixture')
      File.symlink(directory, File.join(directory, 'alias'))
      check = StandaloneAppCheck.new(File.join(directory, 'alias', 'Write.app'), unsigned: true)
      assert check.inside_app?(member)
    end
  end

  def test_wrapper_rejects_reusing_suite_derived_data
    Dir.mktmpdir do |directory|
      FileUtils.mkdir_p(File.join(directory, 'Build', 'Products', 'Debug', 'Write.app'))
      wrapper = File.expand_path('../build-standalone.sh', __dir__)
      _output, error, status = Open3.capture3('bash', wrapper, 'Write', '--derived-data', directory, '--unsigned')
      refute status.success?
      assert_match(/separate DerivedData path/, error)
    end
  end
end

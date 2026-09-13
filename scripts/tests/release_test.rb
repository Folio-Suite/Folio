# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'json'

class ReleaseTest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir('folio-release-test-')
    @repo = File.join(@temporary, 'source')
    FileUtils.mkdir_p(File.join(@repo, 'Config'))
    File.write(File.join(@repo, 'Config/Version.xcconfig'), "MARKETING_VERSION = 0.1.0\nCURRENT_PROJECT_VERSION = 1\n")
    system('git', 'init', '-q', @repo, exception: true)
    FileUtils.mkdir_p(File.join(@repo, 'scripts'))
    FileUtils.cp(File.expand_path('../increment-build.rb', __dir__), File.join(@repo, 'scripts/increment-build.rb'))
    git('add', '.')
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'Fixture')
    @candidate = File.join(@temporary, 'candidate')
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  def git(*args)
    output, status = Open3.capture2e('git', '-C', @repo, *args)
    assert status.success?, output
    output.strip
  end

  def cli(*args)
    Open3.capture2e('ruby', File.expand_path('../release.rb', __dir__), *args, chdir: @repo)
  end

  def succeeds(*args)
    output, status = cli(*args)
    assert status.success?, output
    output
  end

  def make_products
    products = File.join(@temporary, 'Products')
    bundles = %w[Write.app Research.app Composer.app FolioKit.framework WriteKit.framework ResearchKit.framework ComposerKit.framework]
    bundles += %w[Write Research Composer].map { |app| "#{app}.app/Contents/XPCServices/#{app}XPCService.xpc" }
    bundles << 'Write.app/Contents/Frameworks/WriteKit.framework'
    bundles.each do |bundle|
      name = File.basename(bundle).sub(/\.(app|framework|xpc)$/, '')
      relative = bundle.end_with?('.framework') ? 'Resources/Info.plist' : 'Contents/Info.plist'
      path = File.join(products, bundle, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>dev.foliosuite.#{name}</string>
        <key>CFBundleShortVersionString</key><string>0.1.0</string>
        <key>CFBundleVersion</key><string>1</string>
        </dict></plist>
      XML
    end
    products
  end

  def test_verifier_rejects_a_mismatched_embedded_framework
    products = make_products
    succeeds('verify', '--products', products)
    path = File.join(products, 'Write.app/Contents/Frameworks/WriteKit.framework/Resources/Info.plist')
    File.write(path, File.read(path).sub('<string>1</string>', '<string>9</string>'))
    output, status = cli('verify', '--products', products)
    refute status.success?, output
    assert_includes output, 'Write.app/Contents/Frameworks/WriteKit.framework'
    assert_includes output, 'expected 0.1.0 (1)'
  end


  def increment(phase, action)
    Open3.capture2e({ 'ACTION' => action }, 'ruby', File.join(@repo, 'scripts/increment-build.rb'), phase)
  end

  def test_suite_build_and_archive_each_advance_once
    output, status = increment('build', 'build')
    assert status.success?, output
    assert_includes File.read(File.join(@repo, 'Config/Version.xcconfig')), 'CURRENT_PROJECT_VERSION = 2'
    output, status = increment('build', 'install')
    assert status.success?, output
    assert_includes File.read(File.join(@repo, 'Config/Version.xcconfig')), 'CURRENT_PROJECT_VERSION = 3'
    increment('build', 'clean')
    assert_includes File.read(File.join(@repo, 'Config/Version.xcconfig')), 'CURRENT_PROJECT_VERSION = 3'
  end

  def test_concurrent_counter_updates_are_not_lost
    results = 4.times.map { Thread.new { increment('build', 'build') } }.map(&:value)
    results.each { |output, status| assert status.success?, output }
    assert_includes File.read(File.join(@repo, 'Config/Version.xcconfig')), 'CURRENT_PROJECT_VERSION = 5'
  end

  def test_invalid_counter_is_not_rewritten
    path = File.join(@repo, 'Config/Version.xcconfig')
    File.write(path, 'invalid configuration')
    output, status = increment('build', 'build')
    refute status.success?, output
    assert_equal 'invalid configuration', File.read(path)
  end

  def test_prepare_records_completed_build_without_allocating
    output, status = increment('build', 'build')
    assert status.success?, output
    products = make_products
    Dir.glob(File.join(products, '**/Info.plist')).each do |path|
      File.write(path, File.read(path).sub('<string>1</string>', '<string>2</string>'))
    end
    before = File.read(File.join(@repo, 'Config/Version.xcconfig'))
    succeeds('prepare', '--products', products, '--output', @candidate)
    candidate = JSON.parse(File.read(File.join(@candidate, 'release.json')))
    assert_equal '2', candidate['build']
    assert_equal true, candidate['dirty']
    assert_equal git('rev-parse', 'HEAD'), candidate['revision']
    assert_includes candidate['source_patch'], '+CURRENT_PROJECT_VERSION = 2'
    assert_equal before, File.read(File.join(@repo, 'Config/Version.xcconfig'))
    succeeds('verify', '--products', products, '--candidate', @candidate)
  end

  def test_prepare_rejects_uncommitted_source_changes
    File.write(File.join(@repo, 'uncommitted.m'), '// source change')
    output, status = cli('prepare', '--products', make_products, '--output', @candidate)
    refute status.success?, output
    assert_includes output, 'Source is dirty'
  end
end

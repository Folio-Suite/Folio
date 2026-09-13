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
    git('add', '.')
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'Fixture')
    @ledger = File.join(@temporary, 'numbers.json')
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

  def test_prepare_allocates_once_and_reuses_candidate_without_changing_source
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '1')
    succeeds('prepare', '--ledger', @ledger, '--output', @candidate)
    first = JSON.parse(File.read(File.join(@candidate, 'release.json')))
    assert_equal '0.1.0', first.fetch('version')
    assert_equal '2', first.fetch('build')
    assert_equal git('rev-parse', 'HEAD'), first.fetch('revision')
    assert_equal false, first.fetch('dirty')
    succeeds('prepare', '--ledger', @ledger, '--output', @candidate)
    assert_equal first, JSON.parse(File.read(File.join(@candidate, 'release.json')))
    assert_equal '', git('status', '--porcelain')
    second = File.join(@temporary, 'second')
    succeeds('prepare', '--ledger', @ledger, '--output', second)
    assert_equal '3', JSON.parse(File.read(File.join(second, 'release.json'))).fetch('build')
  end
  def test_preparation_rejects_output_that_would_dirty_the_source
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '1')
    output, status = cli('prepare', '--ledger', @ledger, '--output', File.join(@repo, 'candidate'))
    refute status.success?, output
    assert_includes output, 'ignored'
    assert_equal '', git('status', '--porcelain')
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

  def test_candidate_verification_uses_recorded_identity
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '1')
    succeeds('prepare', '--ledger', @ledger, '--output', @candidate)
    products = make_products
    Dir.glob(File.join(products, '**/Info.plist')).each do |path|
      File.write(path, File.read(path).sub('<string>1</string>', '<string>2</string>'))
    end
    succeeds('verify', '--products', products, '--candidate', @candidate)
    output, status = cli('verify', '--products', products)
    refute status.success?, output
    assert_includes output, 'expected 0.1.0 (1)'
  end

  def test_build_refuses_changed_source_before_invoking_xcode
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '1')
    succeeds('prepare', '--ledger', @ledger, '--output', @candidate)
    File.write(File.join(@repo, 'uncommitted.txt'), 'Changed source')
    output, status = cli('build', '--candidate', @candidate)
    refute status.success?, output
    assert_includes output, 'Source is dirty'
  end

  def test_concurrent_preparations_reserve_distinct_numbers
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '40')
    results = 4.times.map do |index|
      Thread.new { cli('prepare', '--ledger', @ledger, '--output', "#{@candidate}-#{index}") }
    end.map(&:value)
    results.each { |output, status| assert status.success?, output }
    numbers = 4.times.map { |i| JSON.parse(File.read("#{@candidate}-#{i}/release.json")).fetch('build').to_i }
    assert_equal [41, 42, 43, 44], numbers.sort
  end

  def test_ledger_cannot_be_reset_and_missing_bundles_are_rejected
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '9')
    output, status = cli('init-ledger', '--ledger', @ledger, '--last-build', '1')
    refute status.success?, output
    assert_includes output, 'never be reset'
    products = make_products
    FileUtils.rm_rf(File.join(products, 'Composer.app/Contents/XPCServices'))
    output, status = cli('verify', '--products', products)
    refute status.success?, output
    assert_includes output, 'Missing shipping bundle'
  end

  def test_preparation_rejects_dirty_source_and_corrupt_ledger
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '1')
    path = File.join(@repo, 'Config/Version.xcconfig')
    original = File.read(path)
    File.write(path, original + "// dirty source\n")
    output, status = cli('prepare', '--ledger', @ledger, '--output', @candidate)
    refute status.success?, output
    assert_includes output, 'Source is dirty'
    refute File.exist?(@candidate)
    File.write(path, original)
    File.write(@ledger, '{invalid')
    output, status = cli('prepare', '--ledger', @ledger, '--output', @candidate)
    refute status.success?, output
    refute File.exist?(@candidate)
  end

  def test_reuse_detects_a_ledger_restored_behind_the_candidate
    succeeds('init-ledger', '--ledger', @ledger, '--last-build', '1')
    backup = File.read(@ledger)
    succeeds('prepare', '--ledger', @ledger, '--output', @candidate)
    File.write(@ledger, backup)
    output, status = cli('prepare', '--ledger', @ledger, '--output', @candidate)
    refute status.success?, output
    assert_includes output, 'behind'
  end

  def test_verifier_ignores_xcode_test_runner_products
    products = make_products
    runner = File.join(products, 'ResearchUITests-Runner.app/Contents')
    FileUtils.mkdir_p(runner)
    File.write(File.join(runner, 'Info.plist'), '<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>dev.foliosuite.ResearchUITests.xctrunner</string></dict></plist>')
    succeeds('verify', '--products', products)
  end

  def test_verifier_rejects_wrong_identity_in_a_known_embedded_kit
    products = make_products
    path = File.join(products, 'Write.app/Contents/Frameworks/WriteKit.framework/Resources/Info.plist')
    File.write(path, File.read(path).sub('dev.foliosuite.WriteKit', 'invalid.WriteKit'))
    output, status = cli('verify', '--products', products)
    refute status.success?, output
    assert_includes output, 'Unexpected bundle identifier'
  end

end

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
    @undokit_origin = File.join(@temporary, 'undokit-origin')
    FileUtils.mkdir_p(@undokit_origin)
    File.write(File.join(@undokit_origin, 'Project.xcconfig'), "MARKETING_VERSION = 0.1.0\nCURRENT_PROJECT_VERSION = 1\n")
    system('git', 'init', '-q', @undokit_origin, exception: true)
    repository_git(@undokit_origin, 'add', '.')
    repository_git(@undokit_origin, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'UndoKit fixture')
    repository_git(@undokit_origin, '-c', 'tag.gpgsign=false', 'tag', '0.1.0')
    git('-c', 'protocol.file.allow=always', 'submodule', 'add', '-q', @undokit_origin, 'UndoKit')
    @undokit = File.join(@repo, 'UndoKit')
    git('add', '.')
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Fixture')
    @candidate = File.join(@temporary, 'candidate')
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  def git(*args)
    repository_git(@repo, *args)
  end

  def repository_git(repository, *args)
    output, status = Open3.capture2e('git', '-C', repository, *args)
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

  def make_products(suite_version: '0.1.0', suite_build: '1')
    products = File.join(@temporary, 'Products')
    bundles = %w[Write.app Research.app Composer.app FolioKit.framework WriteKit.framework ResearchKit.framework ComposerKit.framework UndoKit.framework TypographyKit.framework]
    bundles += %w[Write Research Composer].map { |app| "#{app}.app/Contents/XPCServices/#{app}XPCService.xpc" }
    bundles << 'Write.app/Contents/Frameworks/WriteKit.framework'
    bundles += %w[Write Research Composer].map { |app| "#{app}.app/Contents/Frameworks/UndoKit.framework" }
    bundles.each do |bundle|
      name = File.basename(bundle).sub(/\.(app|framework|xpc)$/, '')
      relative = bundle.end_with?('.framework') ? 'Resources/Info.plist' : 'Contents/Info.plist'
      path = File.join(products, bundle, relative)
      version, build = name == 'UndoKit' ? ['0.1.0', '1'] : [suite_version, suite_build]
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>dev.foliosuite.#{name}</string>
        <key>CFBundleShortVersionString</key><string>#{version}</string>
        <key>CFBundleVersion</key><string>#{build}</string>
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


  def test_prepare_records_completed_build_without_changing_identity
    products = make_products
    before = File.read(File.join(@repo, 'Config/Version.xcconfig'))
    succeeds('prepare', '--products', products, '--output', @candidate)
    candidate = JSON.parse(File.read(File.join(@candidate, 'release.json')))
    assert_equal '1', candidate['build']
    assert_equal false, candidate['dirty']
    assert_equal git('rev-parse', 'HEAD'), candidate['revision']
    assert_equal 'Shared configuration', candidate['numbering']
    refute candidate.key?('source_patch')
    assert_equal before, File.read(File.join(@repo, 'Config/Version.xcconfig'))
    succeeds('verify', '--products', products, '--candidate', @candidate)
  end

  def test_prepare_records_pinned_undokit_identity
    succeeds('prepare', '--products', make_products, '--output', @candidate)
    candidate = JSON.parse(File.read(File.join(@candidate, 'release.json')))
    assert_equal({ 'revision' => repository_git(@undokit, 'rev-parse', 'HEAD'),
                   'version' => '0.1.0', 'build' => '1', 'tag' => '0.1.0' }, candidate['undokit'])
  end

  def test_prepare_rejects_untracked_undokit_source_even_when_submodules_are_ignored
    git('config', 'diff.ignoreSubmodules', 'all')
    git('config', 'submodule.UndoKit.ignore', 'all')
    File.write(File.join(@undokit, 'Uncommitted.swift'), '// new source')
    output, status = cli('prepare', '--products', make_products, '--output', @candidate)
    refute status.success?, output
    assert_includes output, 'UndoKit source is dirty'
    refute File.exist?(@candidate)
  end

  def test_prepare_rejects_a_different_undokit_revision_even_when_submodules_are_ignored
    git('config', 'diff.ignoreSubmodules', 'all')
    git('config', 'submodule.UndoKit.ignore', 'all')
    File.write(File.join(@undokit, 'Committed.swift'), '// different revision')
    repository_git(@undokit, 'add', '.')
    repository_git(@undokit, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                   '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Different dependency')
    output, status = cli('prepare', '--products', make_products, '--output', @candidate)
    refute status.success?, output
    assert_includes output, 'UndoKit revision does not match the committed submodule pin'
    refute File.exist?(@candidate)
  end

  def test_prepare_and_build_require_an_initialized_undokit_submodule
    git('submodule', 'deinit', '-f', 'UndoKit')
    [%w[prepare --output], %w[build --candidate]].each do |command, option|
      output, status = cli(command, option, @candidate, '--products', make_products)
      refute status.success?, output
      assert_includes output, 'UndoKit submodule is not initialized'
      refute File.exist?(@candidate)
    end
  end

  def test_verifier_accepts_undokit_version_independent_of_the_suite
    File.write(File.join(@repo, 'Config/Version.xcconfig'), "MARKETING_VERSION = 0.2.0\nCURRENT_PROJECT_VERSION = 7\n")
    git('add', 'Config/Version.xcconfig')
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false',
        'commit', '-qm', 'Suite version')
    succeeds('verify', '--products', make_products(suite_version: '0.2.0', suite_build: '7'))
  end

  def test_candidate_verifier_requires_valid_recorded_undokit_identity
    products = make_products
    succeeds('prepare', '--products', products, '--output', @candidate)
    path = File.join(@candidate, 'release.json')
    candidate = JSON.parse(File.read(path))
    invalid = [nil, {}, candidate['undokit'].merge('revision' => 'not-a-revision'),
               candidate['undokit'].merge('version' => '0.1'), candidate['undokit'].merge('build' => '0'),
               candidate['undokit'].merge('tag' => 1)]
    invalid.each do |identity|
      File.write(path, JSON.generate(candidate.merge('undokit' => identity)))
      output, status = cli('verify', '--products', products, '--candidate', @candidate)
      refute status.success?, output
      assert_includes output, 'Invalid candidate UndoKit identity'
    end
  end

  def test_candidate_verification_uses_recorded_identity_without_current_source
    File.write(File.join(@repo, 'Config/Version.xcconfig'), "MARKETING_VERSION = 0.2.0\nCURRENT_PROJECT_VERSION = 7\n")
    git('add', 'Config/Version.xcconfig')
    git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false',
        'commit', '-qm', 'Suite version')
    products = make_products(suite_version: '0.2.0', suite_build: '7')
    succeeds('prepare', '--products', products, '--output', @candidate)
    git('submodule', 'deinit', '-f', 'UndoKit')
    File.write(File.join(@repo, 'Config/Version.xcconfig'), "MARKETING_VERSION = 0.9.0\nCURRENT_PROJECT_VERSION = 99\n")
    succeeds('verify', '--products', products, '--candidate', @candidate)
  end

  def test_verifier_rejects_mismatched_installed_and_embedded_undokit
    products = make_products
    bundles = ['UndoKit.framework'] + %w[Write Research Composer].map do |app|
      "#{app}.app/Contents/Frameworks/UndoKit.framework"
    end
    bundles.each do |bundle|
      path = File.join(products, bundle, 'Resources/Info.plist')
      original = File.read(path)
      File.write(path, original.sub('<string>0.1.0</string>', '<string>0.2.0</string>'))
      output, status = cli('verify', '--products', products)
      refute status.success?, output
      assert_includes output, bundle
      assert_includes output, 'expected 0.1.0 (1)'
      File.write(path, original)
    end
  end

  def test_build_rejects_modified_undokit_source_even_when_submodules_are_ignored
    git('config', 'diff.ignoreSubmodules', 'all')
    git('config', 'submodule.UndoKit.ignore', 'all')
    File.write(File.join(@undokit, 'Project.xcconfig'), "MARKETING_VERSION = 0.2.0\nCURRENT_PROJECT_VERSION = 3\n")
    output, status = cli('build', '--candidate', @candidate)
    refute status.success?, output
    assert_includes output, 'UndoKit source is dirty'
    refute File.exist?(@candidate)
  end

  def test_prepare_rejects_uncommitted_version_changes
    path = File.join(@repo, 'Config/Version.xcconfig')
    File.write(path, File.read(path).sub('CURRENT_PROJECT_VERSION = 1', 'CURRENT_PROJECT_VERSION = 2'))
    output, status = cli('prepare', '--products', make_products, '--output', @candidate)
    refute status.success?, output
    assert_includes output, 'Source is dirty'
  end

  def test_prepare_rejects_uncommitted_source_changes
    File.write(File.join(@repo, 'uncommitted.m'), '// source change')
    output, status = cli('prepare', '--products', make_products, '--output', @candidate)
    refute status.success?, output
    assert_includes output, 'Source is dirty'
  end
end

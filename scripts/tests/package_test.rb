# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT
require 'minitest/autorun'
require 'tmpdir'
require 'open3'
require 'json'
require 'fileutils'

class PackageTest < Minitest::Test
  def test_missing_candidate_produces_no_package
    Dir.mktmpdir('folio-package-test-') do |directory|
      output = File.join(directory, 'output')
      message, status = Open3.capture2e('ruby', File.expand_path('../package.rb', __dir__),
        '--candidate', File.join(directory, 'missing'), '--products', directory, '--output', output)
      refute status.success?
      assert_includes message, 'release.json'
      refute File.exist?(output)
    end
  end
end

class PackagePayloadTest < Minitest::Test
  def test_package_contains_only_shipping_bundles_at_fixed_locations
    Dir.mktmpdir('folio-package-payload-') do |directory|
      products = File.join(directory, 'products')
      candidate = File.join(directory, 'candidate')
      FileUtils.mkdir_p(candidate)
      File.write(File.join(candidate, 'release.json'), JSON.generate({
        'schema' => 1, 'numbering' => 'Folio scheme', 'dirty' => false,
        'revision' => 'a' * 40, 'version' => '0.1.0', 'build' => '7' }))
      bundles = %w[Write.app Research.app Composer.app FolioKit.framework WriteKit.framework ResearchKit.framework ComposerKit.framework]
      bundles += %w[Write Research Composer].map { |app| "#{app}.app/Contents/XPCServices/#{app}XPCService.xpc" }
      bundles.each do |bundle|
        name = File.basename(bundle).split('.').first
        path = File.join(products, bundle, bundle.end_with?('.framework') ? 'Resources/Info.plist' : 'Contents/Info.plist')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.generate({ 'CFBundleIdentifier' => "dev.foliosuite.#{name}",
          'CFBundleShortVersionString' => '0.1.0', 'CFBundleVersion' => '7', 'CFBundleExecutable' => name,
          'CFBundlePackageType' => bundle.end_with?('.framework') ? 'FMWK' : 'APPL' }))
        system('/usr/bin/plutil', '-convert', 'xml1', path, exception: true)
        executable = File.join(products, bundle, bundle.end_with?('.framework') ? name : "Contents/MacOS/#{name}")
        FileUtils.mkdir_p(File.dirname(executable))
        FileUtils.cp('/usr/bin/true', executable)
      end
      FileUtils.mkdir_p(File.join(products, 'WriteTests.xctest'))
      output = File.join(directory, 'package')
      message, status = Open3.capture2e('ruby', File.expand_path('../package.rb', __dir__),
        '--candidate', candidate, '--products', products, '--output', output)
      assert status.success?, message
      expanded = File.join(directory, 'expanded')
      message, status = Open3.capture2e('/usr/sbin/pkgutil', '--expand-full', File.join(output, 'Folio-0.1.0.7.pkg'), expanded)
      assert status.success?, message
      assert File.directory?(File.join(expanded, 'Payload/Applications/Folio/Research.app/Contents/XPCServices/ResearchXPCService.xpc'))
      assert File.directory?(File.join(expanded, 'Payload/Library/Frameworks/FolioKit.framework'))
      assert_empty Dir.glob(File.join(expanded, '**', '*.xctest'))
      assert_includes File.read(File.join(expanded, 'PackageInfo')), 'identifier="dev.foliosuite.Suite"'
      assert_includes File.read(File.join(expanded, 'PackageInfo')), 'version="0.1.0.7"'
      manifest = JSON.parse(File.read(File.join(output, 'package.json')))
      assert_equal '7', manifest['identity']['build']
      assert_equal 64, manifest['package_sha256'].size
      File.unlink(File.join(products, 'Write.app/Contents/MacOS/Write'))
      message, status = Open3.capture2e('ruby', File.expand_path('../package.rb', __dir__),
        '--candidate', candidate, '--products', products, '--output', output + '-invalid')
      refute status.success?, message
      assert_includes message, 'Missing executable'
      refute File.exist?(output + '-invalid')
    end
  end
end

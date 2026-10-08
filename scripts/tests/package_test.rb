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
        'schema' => 2, 'numbering' => 'Shared configuration', 'dirty' => false,
        'revision' => 'a' * 40, 'version' => '0.1.0', 'build' => '7',
        'undokit' => { 'revision' => 'b' * 40, 'version' => '0.2.0', 'build' => '3', 'tag' => '0.2.0' } }))
      bundles = %w[Write.app Research.app Composer.app FolioKit.framework WriteKit.framework ResearchKit.framework ComposerKit.framework UndoKit.framework TypographyKit.framework]
      bundles += %w[Write Research Composer].map { |app| "#{app}.app/Contents/XPCServices/#{app}XPCService.xpc" }
      bundles.each do |bundle|
        name = File.basename(bundle).split('.').first
        path = File.join(products, bundle, bundle.end_with?('.framework') ? 'Resources/Info.plist' : 'Contents/Info.plist')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.generate({ 'CFBundleIdentifier' => "dev.foliosuite.#{name}",
          'CFBundleShortVersionString' => (name == 'UndoKit' ? '0.2.0' : '0.1.0'),
          'CFBundleVersion' => (name == 'UndoKit' ? '3' : '7'), 'CFBundleExecutable' => name,
          'CFBundlePackageType' => bundle.end_with?('.framework') ? 'FMWK' : 'APPL' }))
        system('/usr/bin/plutil', '-convert', 'xml1', path, exception: true)
        executable = File.join(products, bundle, bundle.end_with?('.framework') ? name : "Contents/MacOS/#{name}")
        FileUtils.mkdir_p(File.dirname(executable))
        FileUtils.cp('/usr/bin/true', executable)
      end
      resources = %w[Write.app/Contents/Resources/Base.lproj/Main.storyboardc/MainMenu.nib
        Research.app/Contents/Resources/Base.lproj/Main.storyboardc/MainMenu.nib
        ResearchKit.framework/Resources/Base.lproj/Library.storyboardc/Document\ Window\ Controller.nib
        Composer.app/Contents/Resources/Base.lproj/Main.storyboardc/MainMenu.nib
        ComposerKit.framework/Resources/Base.lproj/Preview.storyboardc/Document\ Window\ Controller.nib
        WriteKit.framework/Resources/Work.momd/WorkV1.mom
        WriteKit.framework/Resources/Base.lproj/Editor.storyboardc/EditorWindow.nib
        WriteKit.framework/Resources/Base.lproj/Editor.storyboardc/Editor.nib
        WriteKit.framework/Resources/Assets.car
        UndoKit.framework/Resources/History.momd/HistoryV1.mom]
      resources.each do |resource|
        path = File.join(products, resource)
        FileUtils.mkdir_p(File.dirname(path)); File.write(path, 'fixture resource')
      end
      FileUtils.mkdir_p(File.join(products, 'WriteTests.xctest'))

      package_frameworks = %w[
        Algorithms_-79BF82D738C97CDC_PackageProduct
        Collections_47BB0D94F2814A8A_PackageProduct
        Defaults_-6679B2A78FDF15C0_PackageProduct
        RealModule_20918C39686D2FF4_PackageProduct
      ]
      %w[Write Research Composer].each do |app|
        framework_root = File.join(products, "#{app}.app/Contents/Frameworks")
        package_frameworks.each do |name|
          framework = File.join(framework_root, "#{name}.framework")
          resources_directory = File.join(framework, 'Resources')
          FileUtils.mkdir_p(resources_directory)
          executable = File.join(framework, name)
          FileUtils.cp('/usr/bin/true', executable)
          info = File.join(resources_directory, 'Info.plist')
          File.write(info, JSON.generate({ 'CFBundleIdentifier' => "test.#{name}",
            'CFBundleExecutable' => name, 'CFBundlePackageType' => 'FMWK' }))
          system('/usr/bin/plutil', '-convert', 'xml1', info, exception: true)
          File.write(File.join(resources_directory, 'package-marker.txt'), "package marker #{name}")
          system('/usr/bin/codesign', '--remove-signature', executable, exception: true)
          system('/usr/bin/codesign', '--force', '--sign', '-', '--timestamp=none', framework, exception: true)
        end
        File.write(File.join(framework_root, 'libswiftCompatibilitySpan.dylib'), 'Swift compatibility runtime')
      end

      # A /tmp-style parent alias must not make an internal payload link look escaped.
      alias_directory = File.join(directory, 'alias')
      File.symlink(directory, alias_directory)
      File.symlink('Base.lproj', File.join(products, 'Write.app/Contents/Resources/LocalizedResources'))
      output = File.join(alias_directory, 'package')
      message, status = Open3.capture2e('ruby', File.expand_path('../package.rb', __dir__),
        '--candidate', candidate, '--products', products, '--output', output)
      assert status.success?, message
      expanded = File.join(directory, 'expanded')
      message, status = Open3.capture2e('/usr/sbin/pkgutil', '--expand-full', File.join(output, 'Folio-0.1.0.7.pkg'), expanded)
      assert status.success?, message
      assert File.directory?(File.join(expanded, 'Payload/Applications/Folio/Research.app/Contents/XPCServices/ResearchXPCService.xpc'))
      assert File.directory?(File.join(expanded, 'Payload/Library/Frameworks/FolioKit.framework'))
      package_frameworks.each do |name|
        path = File.join(expanded, 'Payload/Applications/Folio/Write.app/Contents/Frameworks', "#{name}.framework", name)
        marker = File.join(File.dirname(path), 'Resources/package-marker.txt')
        assert_equal "package marker #{name}", File.read(marker)
        framework = File.dirname(path)
        message, status = Open3.capture2e('/usr/bin/codesign', '--verify', '--deep', '--strict', framework)
        assert status.success?, message
        assert File.file?(File.join(expanded, 'Payload/Applications/Folio/Research.app/Contents/Frameworks', "#{name}.framework", name))
        assert File.file?(File.join(expanded, 'Payload/Applications/Folio/Composer.app/Contents/Frameworks', "#{name}.framework", name))
      end
      assert_equal 'Swift compatibility runtime', File.read(File.join(expanded,
        'Payload/Applications/Folio/Write.app/Contents/Frameworks/libswiftCompatibilitySpan.dylib'))
      assert File.symlink?(File.join(expanded, 'Payload/Applications/Folio/Write.app/Contents/Resources/LocalizedResources'))
      assert_empty Dir.glob(File.join(expanded, '**', '*.xctest'))
      assert_includes File.read(File.join(expanded, 'PackageInfo')), 'identifier="dev.foliosuite.Suite"'
      assert_includes File.read(File.join(expanded, 'PackageInfo')), 'version="0.1.0.7"'
      manifest = JSON.parse(File.read(File.join(output, 'package.json')))
      assert_equal '7', manifest['identity']['build']
      assert_equal '0.2.0', manifest['identity']['undokit']['version']
      assert_equal 'b' * 40, manifest['identity']['undokit']['revision']
      assert_equal 64, manifest['package_sha256'].size
      history_model = File.join(products, 'UndoKit.framework/Resources/History.momd/HistoryV1.mom')
      File.unlink(history_model)
      assert_package_rejected(candidate, products, output + '-no-history-model', 'Missing required resource')
      File.write(history_model, 'fixture resource')
      missing_resource = File.join(products, 'WriteKit.framework/Resources/Work.momd/WorkV1.mom')
      File.unlink(missing_resource)
      message, status = Open3.capture2e('ruby', File.expand_path('../package.rb', __dir__),
        '--candidate', candidate, '--products', products, '--output', output + '-no-model')
      refute status.success?, message
      assert_includes message, 'Missing required resource'
      refute File.exist?(output + '-no-model')
      File.write(missing_resource, 'fixture resource')
      File.unlink(File.join(products, 'Write.app/Contents/MacOS/Write'))
      message, status = Open3.capture2e('ruby', File.expand_path('../package.rb', __dir__),
        '--candidate', candidate, '--products', products, '--output', output + '-invalid')
      refute status.success?, message
      assert_includes message, 'Missing executable'
      refute File.exist?(output + '-invalid')

      FileUtils.cp('/usr/bin/true', File.join(products, 'Write.app/Contents/MacOS/Write'))
      suite_framework = File.join(products, 'Write.app/Contents/Frameworks/FolioKit.framework')
      FileUtils.cp_r(File.join(products, 'FolioKit.framework'), suite_framework)
      assert_package_rejected(candidate, products, output + '-suite-kit', 'Unexpected embedded framework')
      FileUtils.rm_rf(suite_framework)

      unknown_framework = File.join(products, 'Write.app/Contents/Frameworks/Other_123_PackageProduct.framework')
      FileUtils.mkdir_p(unknown_framework)
      write_non_suite_framework_info(unknown_framework)
      assert_package_rejected(candidate, products, output + '-unknown-framework', 'Unexpected embedded framework')
      FileUtils.rm_rf(unknown_framework)

      misplaced_framework = File.join(products, 'Write.app/Contents/Resources/Algorithms_123_PackageProduct.framework')
      FileUtils.mkdir_p(misplaced_framework)
      write_non_suite_framework_info(misplaced_framework)
      assert_package_rejected(candidate, products, output + '-misplaced-framework', 'Unexpected embedded framework')
      FileUtils.rm_rf(misplaced_framework)

      kit_nested_framework = File.join(products, 'FolioKit.framework/Contents/Frameworks/Algorithms_123_PackageProduct.framework')
      FileUtils.mkdir_p(kit_nested_framework)
      write_non_suite_framework_info(kit_nested_framework)
      assert_package_rejected(candidate, products, output + '-kit-nested-framework', 'Unexpected embedded framework')
      FileUtils.rm_rf(kit_nested_framework)

      unexpected_runtime = File.join(products, 'Write.app/Contents/Frameworks/libswiftCore.dylib')
      File.write(unexpected_runtime, 'unexpected runtime')
      assert_package_rejected(candidate, products, output + '-unexpected-runtime', 'Unexpected development product')
      File.unlink(unexpected_runtime)

      misplaced_runtime = File.join(products, 'Write.app/Contents/Resources/libswiftCompatibilitySpan.dylib')
      File.write(misplaced_runtime, 'misplaced compatibility runtime')
      assert_package_rejected(candidate, products, output + '-misplaced-runtime', 'Unexpected development product')
      File.unlink(misplaced_runtime)

      embedded_tests = File.join(products, 'Write.app/Contents/Frameworks/WriteTests.xctest')
      FileUtils.mkdir_p(embedded_tests)
      assert_package_rejected(candidate, products, output + '-embedded-tests', 'Unexpected development product')
      FileUtils.rm_rf(embedded_tests)
    end
  end

  private

  def assert_package_rejected(candidate, products, output, expected_message)
    message, status = Open3.capture2e('ruby', File.expand_path('../package.rb', __dir__),
      '--candidate', candidate, '--products', products, '--output', output)
    refute status.success?, message
    assert_includes message, expected_message
    refute File.exist?(output)
  end

  def write_non_suite_framework_info(framework)
    info = File.join(framework, 'Resources/Info.plist')
    FileUtils.mkdir_p(File.dirname(info))
    File.write(info, JSON.generate({ 'CFBundleIdentifier' => 'test.unapproved', 'CFBundlePackageType' => 'FMWK' }))
    system('/usr/bin/plutil', '-convert', 'xml1', info, exception: true)
  end
end

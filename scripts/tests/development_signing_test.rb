# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'open3'
require 'rexml/document'
require 'tmpdir'

class DevelopmentSigningTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  SCRIPT = File.join(ROOT, 'scripts/prepare-development-frameworks.sh')

  def run_preparation(extra)
    environment = { 'CODE_SIGNING_ALLOWED' => 'YES', 'FOLIO_DISTRIBUTION' => 'suite',
                    'EXPANDED_CODE_SIGN_IDENTITY' => nil, 'BUILT_PRODUCTS_DIR' => nil,
                    'TARGET_BUILD_DIR' => nil, 'FULL_PRODUCT_NAME' => nil }.merge(extra)
    Open3.capture3(environment, 'bash', SCRIPT)
  end

  def test_unsigned_builds_skip_preparation_without_a_host_or_products
    _, errors, status = run_preparation('CODE_SIGNING_ALLOWED' => 'NO')
    assert status.success?, errors
  end

  def test_standalone_wrapper_owns_embedded_signatures
    _, errors, status = run_preparation('FOLIO_DISTRIBUTION' => 'standalone')
    assert status.success?, errors
  end

  def test_ad_hoc_identity_cannot_prepare_shared_runtime_products
    _, errors, status = run_preparation('EXPANDED_CODE_SIGN_IDENTITY' => '-')
    refute status.success?
    assert_includes errors, 'require a team signing identity'
  end

  def test_signed_builds_require_a_real_host_before_touching_frameworks
    _, errors, status = run_preparation({})
    refute status.success?
    assert_includes errors, 'Missing host build directory'
  end

  def test_framework_only_build_can_leave_its_unbuilt_host_for_run_or_test
    Dir.mktmpdir do |directory|
      _, errors, status = run_preparation('TARGET_BUILD_DIR' => directory,
                                         'FULL_PRODUCT_NAME' => 'Unbuilt.app')
      assert status.success?, errors
    end
  end

  def test_every_shared_scheme_prepares_frameworks_from_a_signed_host
    paths = Dir[File.join(ROOT, 'Folio.xcworkspace/xcshareddata/xcschemes/*.xcscheme')]
    paths << File.join(ROOT, 'TypographyKit/TypographyKit.xcodeproj/xcshareddata/xcschemes/TypographyKit.xcscheme')
    paths.each do |path|
      scheme = REXML::Document.new(File.read(path))
      actions = REXML::XPath.match(scheme, './Scheme/BuildAction/PostActions/ExecutionAction/ActionContent')
      preparation = actions.select { |action| action.attributes['scriptText'].include?('prepare-development-frameworks.sh') }
      assert_equal 1, preparation.length, path
      source = preparation.first.elements['EnvironmentBuildable/BuildableReference']
      assert_match(/\.(app|xctest)\z/, source.attributes['BuildableName'], path)
    end
  end
end

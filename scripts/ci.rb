#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'open3'
require 'rexml/document'
require 'rbconfig'

$stdout.sync = true

# Keep target selection, test plans, and build configurations in Xcode.
Dir.chdir(File.expand_path('..', __dir__))
output = File.expand_path(ARGV.fetch(0, 'build/ci'))
scheme_name = ARGV.fetch(1, 'Folio')
abort 'Unknown shared scheme' unless %w[Folio Write Research Composer].include?(scheme_name)
abort 'Use a new CI output directory for each run' if File.exist?(output)
FileUtils.mkdir_p(output)
scheme = REXML::Document.new(File.read("Folio.xcworkspace/xcshareddata/xcschemes/#{scheme_name}.xcscheme"))
configuration = scheme.elements['Scheme/TestAction'].attributes['buildConfiguration']
version = File.read('Config/Version.xcconfig')

def run(log, *command)
  File.open(log, 'w') do |file|
    file.sync = true
    file.puts(command.inspect)
    Open3.popen2e(*command) do |input, stream, waiter|
      input.close
      stream.each_line { |line| print line; file.write(line) }
      raise "Command failed; see #{log}" unless waiter.value.success?
    end
  end
end

begin
  derived = File.join(output, 'DerivedData')
  common = ['xcodebuild', '-workspace', 'Folio.xcworkspace', '-scheme', scheme_name,
            '-destination', 'platform=macOS', '-derivedDataPath', derived]
  # Local Xcode uses the contributor's identity. Hosted jobs select only the
  # dedicated team certificate imported into their temporary keychain.
  signing = []
  if ENV['FOLIO_SIGNING_IDENTITY']
    signing = ["CODE_SIGN_IDENTITY=#{ENV.fetch('FOLIO_SIGNING_IDENTITY')}", 'CODE_SIGN_STYLE=Manual']
  end
  run(File.join(output, 'build.log'), *common, 'build-for-testing', *signing,
      '-resultBundlePath', File.join(output, 'Build.xcresult'))
  products = File.join(derived, 'Build/Products', configuration)
  run(File.join(output, 'signing.log'), RbConfig.ruby, 'scripts/check-ci-signing.rb', products)
  if scheme_name == 'Folio'
    run(File.join(output, 'interfaces.log'), RbConfig.ruby, 'scripts/check-kit-interfaces.rb', products)
    run(File.join(output, 'identity.log'), RbConfig.ruby, 'scripts/release.rb', 'verify', '--products', products)
  end
  run(File.join(output, 'test.log'), *common, 'test-without-building',
      '-resultBundlePath', File.join(output, 'Tests.xcresult'))
ensure
  abort 'CI unexpectedly changed the shared version configuration' unless File.read('Config/Version.xcconfig') == version
end

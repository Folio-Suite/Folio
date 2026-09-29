#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'json'
require 'open3'
require 'set'
require 'tmpdir'

# Check the actual published Swift modules using built products only.
class KitInterfaceCheck
  ROOT = File.expand_path('..', __dir__)
  KITS = %w[FolioKit WriteKit ResearchKit ComposerKit TypographyKit UndoKit].freeze
  PRIVATE_SYMBOLS = { 'FolioKit' => 'TemporaryDirectory', 'WriteKit' => 'WorkStore',
                      'ResearchKit' => 'ResearchKitBundleToken', 'TypographyKit' => 'DrawingRun' }.freeze

  def check(condition, message)
    raise message unless condition
  end

  def capture(*command)
    output, error, status = Open3.capture3(*command)
    check(status.success?, "#{command.first} failed: #{error}")
    output
  end

  def run(arguments)
    check(arguments.length == 1, 'Usage: ruby scripts/check-kit-interfaces.rb PRODUCTS')
    products = File.expand_path(arguments.first)
    sdk = capture('xcrun', '--sdk', 'macosx', '--show-sdk-path').strip
    minimums = Set.new
    KITS.each do |kit|
      framework = "#{products}/#{kit}.framework"
      info = JSON.parse(capture('plutil', '-convert', 'json', '-o', '-', "#{framework}/Resources/Info.plist"))
      minimums.add(info.fetch('LSMinimumSystemVersion'))
      check(Dir.glob("#{framework}/Modules/#{kit}.swiftmodule/*.swiftmodule").any?, "#{kit}: missing public Swift module")
      check(Dir.glob("#{framework}/PrivateHeaders/**/*.h").empty?, "#{kit}: private headers must not ship")
      headers = Dir.glob("#{framework}/Headers/**/*.h").map { |path| File.basename(path) }.to_set
      allowed = Set["#{kit}.h", "#{kit}-Swift.h"]
      check((headers - allowed).empty?, "#{kit}: unexpected exported headers: #{(headers - allowed).to_a}")
    end
    check(minimums == Set['14.0'], "Kits must share macOS 14.0 deployment support: #{minimums.to_a}")
    %w[Core Write Research Composer].each do |directory|
      Dir.glob("#{ROOT}/#{directory}/**/*.swift").each do |source|
        next if source.include?('/Prototypes/') || source.match?(%r{/(?:[^/]*Tests)/})
        check(!File.read(source).match?(/@testable\s+import\s+(?:FolioKit|WriteKit|ResearchKit|ComposerKit)/),
              "#{source}: production hosts must use public Kit imports")
      end
    end
    Dir.mktmpdir('folio-swift-interfaces-') do |stage|
      KITS.each { |kit| FileUtils.cp_r("#{products}/#{kit}.framework", stage, preserve: true) }
      architectures = capture('lipo', '-archs', "#{stage}/FolioKit.framework/FolioKit").split
      check(architectures.to_set == Set['arm64', 'x86_64'], 'Suite products must contain arm64 and x86_64')
      KITS.each do |kit|
        actual = capture('lipo', '-archs', "#{stage}/#{kit}.framework/#{kit}").split.to_set
        check(actual == architectures.to_set, "#{kit}: architecture coverage differs from FolioKit")
      end
      architectures.each do |architecture|
        command = ['xcrun', 'swiftc', '-swift-version', '6', '-sdk', sdk,
                   '-target', "#{architecture}-apple-macosx14.0", '-F', stage,
                   '-module-cache-path', "#{stage}/ModuleCache"]
        check(system(*command, "#{ROOT}/scripts/interface-checks/KitConsumer.swift",
                     *KITS.flat_map { |kit| ['-framework', kit] }, '-o', "#{stage}/consumer-#{architecture}"),
              "Suite public Swift consumer failed for #{architecture}")
        PRIVATE_SYMBOLS.each do |kit, symbol|
          source = "#{stage}/Private.swift"
          File.write(source, "import #{kit}\nlet hidden = #{symbol}.self\n")
          _, error, status = Open3.capture3(*command, '-typecheck', source)
          check(!status.success? && error.include?("cannot find '#{symbol}'"),
                "#{kit}: private symbol test did not reject #{symbol}: #{error}")
        end
      end
      %w[TypographyKit UndoKit].each do |kit|
        isolated = "#{stage}/isolated-#{kit}"
        FileUtils.mkdir_p(isolated)
        FileUtils.cp_r("#{products}/#{kit}.framework", isolated, preserve: true)
        architectures.each do |architecture|
          check(system('xcrun', 'swiftc', '-swift-version', '6', '-sdk', sdk,
                       '-target', "#{architecture}-apple-macosx14.0", '-F', isolated,
                       '-module-cache-path', "#{isolated}/ModuleCache", '-framework', kit,
                       "#{ROOT}/scripts/interface-checks/#{kit}Consumer.swift", '-o', "#{isolated}/consumer-#{architecture}"),
                "#{kit}: standalone Swift consumer failed for #{architecture}")
        end
      end
    end
    puts 'Kit interfaces passed: public Swift consumers, private symbol rejection, standalone framework imports.'
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    KitInterfaceCheck.new.run(ARGV)
  rescue StandardError => error
    warn error.message
    exit 1
  end
end

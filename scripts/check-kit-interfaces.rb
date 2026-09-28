#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'set'
require 'tmpdir'

# Check the published Kit SDK, then compile/link without repository header paths.
class KitInterfaceCheck
  ROOT = File.expand_path('..', __dir__)
  KITS = %w[FolioKit WriteKit ResearchKit ComposerKit].freeze
  IMPLEMENTATIONS = { 'FolioKit' => %w[FKModelFoundations FKPackageSupport FKXMLSupport],
                      'WriteKit' => %w[FWManuscript FWEditor] }.freeze

  def check(condition, message)
    raise message unless condition
  end

  def capture(*command)
    output, error, status = Open3.capture3(*command)
    check(status.success?, "#{command.first} failed: #{error}")
    output
  end

  def run(arguments)
    parser = OptionParser.new do |options|
      options.banner = 'Usage: ruby scripts/check-kit-interfaces.rb PRODUCTS'
      options.separator 'Check published Kit interfaces in Xcode Build/Products/Debug or Release.'
    end
    parser.parse!(arguments)
    check(arguments.length == 1, parser.to_s)
    products = File.expand_path(arguments.first)
    public_headers = {}
    owners = {}
    minimum_versions = Set.new
    KITS.each do |kit|
      module_map = File.read("#{ROOT}/Core/#{kit}/#{kit}.modulemap")
      public_headers[kit] = module_map.scan(/^\s*header "([^"]+)"/).flatten.to_set
      check(!public_headers[kit].empty?, "#{kit}: missing explicit public header list")
      framework = "#{products}/#{kit}.framework"
      info = JSON.parse(capture('plutil', '-convert', 'json', '-o', '-', "#{framework}/Resources/Info.plist"))
      minimum_versions.add(info.fetch('LSMinimumSystemVersion'))
      actual = Dir.glob("#{framework}/Headers/**/*", File::FNM_DOTMATCH)
                  .select { |path| File.file?(path) }.map { |path| path.delete_prefix("#{framework}/Headers/") }.to_set
      check(actual == public_headers[kit],
            "#{kit}: published headers differ: extra=#{(actual - public_headers[kit]).to_a.sort}, missing=#{(public_headers[kit] - actual).to_a.sort}")
      check(File.read("#{framework}/Modules/module.modulemap") == module_map,
            "#{kit}: build did not use the explicit module map")
      check(Dir.glob("#{framework}/PrivateHeaders/**/*.h").empty?, "#{kit}: private headers must not be distributed to hosts")
      imported = File.read("#{framework}/Headers/#{kit}.h").scan(/#import <#{kit}\/([^>]+)>/).flatten.to_set
      check(imported == public_headers[kit] - ["#{kit}.h"], "#{kit}: umbrella and module map disagree")
      Dir.glob("#{ROOT}/Core/#{kit}/**/*.h").each { |path| owners[File.realpath(path)] = kit }
    end
    check(minimum_versions.size == 1, 'Kits must share a coordinated deployment target')
    standalone_minimum_versions = {}
    {'UndoKit' => 'UndoKit', 'TypographyKit' => 'TypographyKit'}.each do |kit, project|
      framework = "#{products}/#{kit}.framework"
      info = JSON.parse(capture('plutil', '-convert', 'json', '-o', '-', "#{framework}/Resources/Info.plist"))
      standalone_minimum_versions[kit] = info.fetch('LSMinimumSystemVersion')
      check(standalone_minimum_versions[kit] == '14.0', "#{kit} must target macOS 14.0")
      if kit == 'UndoKit'
        module_map = File.read("#{ROOT}/#{project}/#{kit}/#{kit}.modulemap")
        check(File.read("#{framework}/Modules/module.modulemap") == module_map,
              'UndoKit build did not use its explicit module map')
      end
    end

    # A Kit's implementation may use local headers; all other callers use published paths.
    by_name = owners.each_with_object({}) { |(path, kit), result| result[File.basename(path)] = [path, kit] }
    %w[Core Write Research Composer].each do |source_directory|
      Dir.glob("#{ROOT}/#{source_directory}/**/*.{h,m,mm}").each do |source|
        own_kit = KITS.find { |kit| source.start_with?("#{ROOT}/Core/#{kit}/") }
        File.read(source).scan(/^\s*#\s*(?:import|include)\s*[<"]([^>"\n]+)[>"]/).flatten.each do |token|
          known = by_name[File.basename(token)]
          next unless known
          header, owner = known
          next if own_kit == owner
          name = File.basename(header)
          check(token == "#{owner}/#{name}" && public_headers[owner].include?(name),
                "#{source.delete_prefix(ROOT + '/')}: use #{owner}'s public interface, not #{token}")
        end
      end
    end
    IMPLEMENTATIONS.each do |kit, names|
      names.each do |name|
        check(Dir.glob("#{products}/#{kit}.framework/**/lib#{name}.dylib").empty?,
              "#{name} must compile into #{kit}, not remain embedded")
      end
    end
    Dir.mktmpdir('folio-kit-interface-') do |stage|
      # Only published bundles are visible, without source trees or Xcode header maps.
      KITS.each { |kit| FileUtils.cp_r("#{products}/#{kit}.framework", stage, preserve: true) }
      sdk = capture('xcrun', '--sdk', 'macosx', '--show-sdk-path').strip
      common = ['xcrun', 'clang', '-isysroot', sdk, '-fobjc-arc', '-fmodules',
                "-mmacosx-version-min=#{minimum_versions.first}", "-fmodules-cache-path=#{stage}/ModuleCache",
                '-F', stage, '-Werror', '-Werror=non-modular-include-in-framework-module']
      frameworks = KITS.flat_map { |kit| ['-framework', kit] }
      fixture = File.read("#{ROOT}/scripts/interface-checks/KitConsumer.m")
      [false, true].each do |modules|
        code = fixture.dup
        KITS.each { |kit| code.gsub!("#import <#{kit}/#{kit}.h>", "@import #{kit};") } if modules
        source = "#{stage}/Consumer.m"
        File.write(source, code)
        check(system(*common, source, '-framework', 'AppKit', *frameworks,
                     '-Wl,-fatal_warnings', '-o', "#{stage}/consumer", chdir: stage), 'Kit consumer compile/link failed')
      end
      owners.each do |header, kit|
        name = File.basename(header)
        next if public_headers[kit].include?(name)
        source = "#{stage}/PrivateImport.m"
        File.write(source, "#import <#{kit}/#{name}>\n")
        _, error, status = Open3.capture3(*common, '-fsyntax-only', source, chdir: stage)
        check(!status.success? && error.include?("'#{kit}/#{name}' file not found"),
              "#{kit}: private header import was not rejected as expected: #{name}\n#{error}")
      end
      IMPLEMENTATIONS.values.flatten.each do |name|
        source = "#{stage}/PrivateModule.m"
        File.write(source, "@import #{name};\n")
        _, error, status = Open3.capture3(*common, '-fsyntax-only', source, chdir: stage)
        check(!status.success? && error.include?("module '#{name}' not found"),
              "Implementation folder must not be a public module: #{name}\n#{error}")
      end

      # These frameworks must be consumable without any Folio Kit beside them.
      # Keep each consumer's framework search path limited to its own staged copy.
      {'UndoKit' => %w[UndoKitConsumer.m UndoKitConsumer.swift],
       'TypographyKit' => %w[TypographyKitConsumer.swift]}.each do |kit, fixture_names|
        isolated = File.join(stage, "isolated-#{kit}")
        FileUtils.mkdir_p(isolated)
        FileUtils.cp_r("#{products}/#{kit}.framework", isolated, preserve: true)
        fixture_names.each do |fixture_name|
          fixture = File.join(ROOT, 'scripts/interface-checks', fixture_name)
          if fixture_name.end_with?('.m')
            command = ['xcrun', 'clang', '-isysroot', sdk, '-fobjc-arc', '-fmodules',
                       "-mmacosx-version-min=#{standalone_minimum_versions.fetch(kit)}", "-fmodules-cache-path=#{isolated}/ModuleCache",
                       '-F', isolated, fixture, '-framework', 'Foundation', '-framework', kit,
                       '-Werror', '-Wl,-fatal_warnings', '-o', "#{isolated}/consumer-objc"]
            check(system(*command, chdir: isolated), 'isolated UndoKit Objective-C consumer compile/link failed')
          else
            %w[arm64 x86_64].each do |architecture|
              command = ['xcrun', 'swiftc', '-sdk', sdk, '-target', "#{architecture}-apple-macosx#{standalone_minimum_versions.fetch(kit)}",
                         '-F', isolated, '-framework', kit, '-module-cache-path', "#{isolated}/ModuleCache",
                         fixture, '-o', "#{isolated}/consumer-#{fixture_name}-#{architecture}"]
              check(system(*command, chdir: isolated), "isolated #{kit} Swift consumer compile/link failed for #{architecture}")
            end
          end
        end
      end
    end
    puts 'Kit interfaces passed: exact published headers, caller imports, isolated compile/link, and private import rejection.'
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

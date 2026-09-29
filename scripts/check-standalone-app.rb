#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'json'
require 'open3'
require 'set'
require_relative 'suite-products'

# Check a built app's embedded Swift framework and resource closure without using DYLD overrides.
class StandaloneAppCheck
  ROOT = File.expand_path('..', __dir__)
  APPS = %w[Write Research Composer].freeze
  KITS = %w[FolioKit WriteKit ResearchKit ComposerKit UndoKit TypographyKit].freeze
  PACKAGE_PRODUCTS = %w[Defaults Collections Algorithms RealModule].freeze
  def self.dependencies(output)
    output.lines.map { |line| line[/^\s+(.+?) \(compatibility version /, 1] }.compact.uniq
  end

  def self.runpaths(output)
    output.scan(/cmd LC_RPATH\s+cmdsize \d+\s+path (.+?) \(offset \d+\)/).flatten.uniq
  end

  def initialize(app, unsigned: false)
    expanded = File.expand_path(app)
    @app = File.directory?(expanded) ? File.realpath(expanded) : expanded
    @name = File.basename(@app, '.app')
    @unsigned = unsigned
    @frameworks = File.join(@app, 'Contents', 'Frameworks')
  end

  def check(condition, message)
    raise message unless condition
  end

  def capture(*command, **options)
    output, error, status = Open3.capture3(*command, **options)
    check(status.success?, "#{command.first} failed: #{error}")
    output
  end

  def plist(path)
    JSON.parse(capture('plutil', '-convert', 'json', '-o', '-', path))
  end

  def verify_sandbox_setting(target)
    project = File.join(ROOT, @name, "#{@name}.xcodeproj", 'project.pbxproj')
    objects = plist(project).fetch('objects')
    item = objects.values.find { |object| object['isa'] == 'PBXNativeTarget' && object['name'] == target }
    check(item, "Missing #{target} target")
    ids = objects.fetch(item.fetch('buildConfigurationList')).fetch('buildConfigurations')
    ids.each do |id|
      configuration = objects.fetch(id)
      check(configuration.fetch('buildSettings').fetch('ENABLE_APP_SANDBOX') == 'YES',
            "#{target} #{configuration.fetch('name')}: App Sandbox must be enabled")
    end
  end

  def inside_app?(path)
    resolved = File.realpath(path)
    resolved == @app || resolved.start_with?("#{@app}/")
  end

  def expand_path(path, binary, executable)
    if path.start_with?('@loader_path/')
      File.expand_path(path.delete_prefix('@loader_path/'), File.dirname(binary))
    elsif path.start_with?('@executable_path/')
      File.expand_path(path.delete_prefix('@executable_path/'), File.dirname(executable))
    else
      path
    end
  end

  def verify_dependency(dependency, binary, executable, runpaths)
    return if dependency.start_with?('/System/Library/', '/usr/lib/')
    if dependency.start_with?('@rpath/')
      member = dependency.delete_prefix('@rpath/')
      candidates = runpaths.map { |runpath| File.join(expand_path(runpath, binary, executable), member) }
      resolved = candidates.find { |path| File.exist?(path) }
      check(resolved, "#{binary}: unresolved embedded dependency #{dependency}")
      check(inside_app?(resolved) || resolved.start_with?('/usr/lib/swift/'),
            "#{binary}: dependency escapes app: #{resolved}")
    elsif dependency.start_with?('@loader_path/', '@executable_path/')
      resolved = expand_path(dependency, binary, executable)
      check(File.exist?(resolved) && inside_app?(resolved), "#{binary}: unresolved relative dependency #{dependency}")
    else
      raise "#{binary}: unexpected dependency #{dependency}"
    end
  end

  def verify_binary(binary, required_runpath: nil, executable: nil)
    check(File.file?(binary), "Missing executable: #{binary}")
    paths = self.class.runpaths(capture('otool', '-l', binary))
    check(paths.include?(required_runpath), "#{binary}: missing #{required_runpath} runpath") if required_runpath
    check(paths.none? { |path| path.start_with?('/') && !path.start_with?('/usr/lib/', '/System/Library/') },
          "#{binary}: has absolute non-system runpath #{paths}")
    self.class.dependencies(capture('otool', '-L', binary)).each do |dependency|
      verify_dependency(dependency, binary, executable || File.join(@app, 'Contents', 'MacOS', @name), paths)
    end
  end

  def verify_frameworks
    check(File.directory?(@frameworks), "Missing app Frameworks directory: #{@frameworks}")
    names = Dir.children(@frameworks)
    KITS.each do |kit|
      path = File.join(@frameworks, "#{kit}.framework")
      check(File.directory?(path) && !File.symlink?(path), "Missing embedded #{kit}.framework")
      binary = File.join(path, 'Versions', 'A', kit)
      verify_binary(binary, required_runpath: '@executable_path/../Frameworks')
      module_path = File.join(path, 'Versions', 'A', 'Modules', "#{kit}.swiftmodule")
      check(Dir.exist?(module_path), "#{kit}: missing Swift module")
      check(Dir.glob("#{path}/Headers/**/*.h").empty?, "#{kit}: unexpected public headers")
    end
    PACKAGE_PRODUCTS.each do |product|
      matches = names.grep(/\A#{product}_.*_PackageProduct\.framework\z/)
      check(matches.length == 1, "Expected one embedded #{product} package product")
      path = File.join(@frameworks, matches.first)
      verify_binary(File.join(path, 'Versions', 'A', matches.first.delete_suffix('.framework')))
    end
    allowed = KITS.map { |kit| "#{kit}.framework" }.to_set
    allowed.merge(names.grep(/\A(?:#{PACKAGE_PRODUCTS.join('|')})_.*_PackageProduct\.framework\z/))
    allowed.add('libswiftCompatibilitySpan.dylib')
    check((names.to_set - allowed).empty?, "Unexpected embedded runtime: #{(names.to_set - allowed).to_a}")
    verify_binary(File.join(@frameworks, 'libswiftCompatibilitySpan.dylib'))
  end

  def verify_resources
    SuiteProducts::REQUIRED_RESOURCES.each do |resource|
      if resource.start_with?("#{@name}.app/")
        path = File.join(@app, resource.delete_prefix("#{@name}.app/"))
      elsif resource.match?(/\A(?:#{KITS.join('|')})\.framework\//)
        path = File.join(@frameworks, resource)
      else
        next
      end
      check(File.file?(path), "Missing standalone resource: #{resource}")
    end
  end

  def verify_signature(path)
    return if @unsigned
    capture('codesign', '--verify', '--deep', '--strict', path)
    xml = capture('codesign', '-d', '--entitlements', '-', '--xml', path)
    entitlements = JSON.parse(capture('plutil', '-convert', 'json', '-o', '-', '--', '-', stdin_data: xml))
    check(entitlements['com.apple.security.app-sandbox'], "#{path}: missing App Sandbox entitlement")
  end

  def run
    check(APPS.include?(@name), "Expected one of #{APPS.join(', ')}.app")
    check(File.directory?(@app), "Missing app: #{@app}")
    check(plist(File.join(@app, 'Contents', 'Info.plist')).fetch('CFBundleIdentifier') == "dev.foliosuite.#{@name}",
          "#{@name}: wrong bundle identifier")
    verify_sandbox_setting(@name)
    verify_sandbox_setting("#{@name}XPCService")
    verify_frameworks
    verify_resources
    verify_binary(File.join(@app, 'Contents', 'MacOS', @name), required_runpath: '@executable_path/../Frameworks')
    service = File.join(@app, 'Contents', 'XPCServices', "#{@name}XPCService.xpc")
    service_binary = File.join(service, 'Contents', 'MacOS', "#{@name}XPCService")
    verify_binary(service_binary, required_runpath: '@executable_path/../../../../Frameworks', executable: service_binary)
    verify_signature(@app)
    verify_signature(service)
    sandbox = @unsigned ? 'sandbox build settings' : 'sandbox entitlements'
    puts "#{@name} standalone closure passed: six Kits, package runtimes, resources, app/XPC paths, #{sandbox}."
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    path = ARGV.shift
    raise 'Usage: ruby scripts/check-standalone-app.rb APP [--unsigned]' unless path && (ARGV.empty? || ARGV == ['--unsigned'])
    StandaloneAppCheck.new(path, unsigned: ARGV.include?('--unsigned')).run
  rescue StandardError => error
    warn error.message
    exit 1
  end
end

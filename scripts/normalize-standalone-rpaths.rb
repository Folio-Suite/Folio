#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'open3'
require_relative 'check-standalone-app'

# Remove Xcode's absolute package-framework build paths from one final app copy.
# Re-sign nested code and the app after changing Mach-O load commands.
class StandaloneRpathNormalizer
  def initialize(app, unsigned: false, identity: nil)
    @app = File.expand_path(app)
    @unsigned = unsigned
    @identity = identity
    @name = File.basename(@app, '.app')
    @frameworks = File.join(@app, 'Contents', 'Frameworks')
  end

  def capture(*command)
    output, error, status = Open3.capture3(*command)
    raise "#{command.first} failed: #{error}" unless status.success?
    output
  end

  def signing_identity
    return @identity if @identity && !@identity.empty?
    output, status = Open3.capture2e('codesign', '-d', '--verbose=4', @app)
    raise output unless status.success?
    identity = output[/^Authority=(.+)$/, 1]
    raise "Cannot determine the original signing identity for #{@app}" unless identity
    identity
  end

  def framework_binary(framework)
    stem = File.basename(framework, '.framework')
    File.join(framework, 'Versions', 'A', stem)
  end

  def normalize(binary)
    raise "Missing binary: #{binary}" unless File.file?(binary)
    paths = StandaloneAppCheck.runpaths(capture('otool', '-l', binary))
    external = paths.select { |path| path.start_with?('/') && !path.start_with?('/usr/lib/', '/System/Library/') }
    external.each { |path| capture('install_name_tool', '-delete_rpath', path, binary) }
    !external.empty?
  end

  def sign(path, identity)
    capture('codesign', '--force', '--sign', identity, '--timestamp=none',
            '--preserve-metadata=identifier,entitlements,flags,runtime', path)
  end

  def run
    raise "Missing app: #{@app}" unless StandaloneAppCheck::APPS.include?(@name) && File.directory?(@app)
    raise "Missing frameworks: #{@frameworks}" unless File.directory?(@frameworks)
    identity = signing_identity unless @unsigned
    changed = []
    framework_paths = Dir.glob(File.join(@frameworks, '*.framework')).sort
    expected = StandaloneAppCheck::KITS.map { |kit| "#{kit}.framework" }
    raise 'Incomplete embedded Kit set' unless (expected - framework_paths.map { |path| File.basename(path) }).empty?
    framework_paths.each do |framework|
      changed << framework if normalize(framework_binary(framework))
    end
    dylibs = Dir.glob(File.join(@frameworks, '*.dylib')).sort
    dylibs.each { |dylib| changed << dylib if normalize(dylib) }
    service = File.join(@app, 'Contents', 'XPCServices', "#{@name}XPCService.xpc")
    service_binary = File.join(service, 'Contents', 'MacOS', "#{@name}XPCService")
    service_changed = normalize(service_binary)
    app_binary = File.join(@app, 'Contents', 'MacOS', @name)
    app_changed = normalize(app_binary)
    unless @unsigned
      changed.each { |path| sign(path, identity) }
      sign(service, identity) if service_changed || !changed.empty?
      sign(@app, identity) if app_changed || service_changed || !changed.empty?
    end
    puts "#{@name}: normalized #{changed.length + (service_changed ? 1 : 0) + (app_changed ? 1 : 0)} Mach-O products."
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    app = ARGV.shift
    raise 'Usage: ruby scripts/normalize-standalone-rpaths.rb APP [--unsigned] [--identity SIGNER]' unless app
    unsigned = false
    identity = nil
    until ARGV.empty?
      argument = ARGV.shift
      case argument
      when '--unsigned' then unsigned = true
      when '--identity' then identity = ARGV.shift
      else raise "Unknown option: #{argument}"
      end
    end
    StandaloneRpathNormalizer.new(app, unsigned: unsigned, identity: identity).run
  rescue StandardError => error
    warn error.message
    exit 1
  end
end

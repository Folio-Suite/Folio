#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'json'
require 'fileutils'
require 'open3'
require 'optparse'
require 'securerandom'
require 'time'
require_relative 'suite-products'

# Public entry point for coordinated Suite release preparation and validation.
class SuiteRelease
  def initialize(arguments)
    @command = arguments.shift
    @options = {}
    OptionParser.new do |parser|
      parser.banner = 'Usage: ruby scripts/release.rb prepare|build|verify [options]'
      %w[output products candidate configuration action].each do |name|
        parser.on("--#{name} VALUE") { |value| @options[name] = value }
      end
    end.parse!(arguments)
    raise 'Unexpected positional arguments' unless arguments.empty?
  end

  def run
    case @command
    when 'prepare' then prepare
    when 'verify' then verify
    when 'build' then build
    else raise 'Expected prepare, build, or verify'
    end
  end

  private

  def option(name)
    @options.fetch(name) { raise "Missing --#{name}" }
  end

  def capture(*command)
    output, status = Open3.capture2e(*command)
    raise output unless status.success?
    output.strip
  end

  def source_identity
    @root = capture('git', 'rev-parse', '--show-toplevel')
    changed = capture('git', '-C', @root, 'diff', '--name-only', 'HEAD').lines.map(&:strip)
    untracked = capture('git', '-C', @root, 'ls-files', '--others', '--exclude-standard')
    raise 'Source is dirty; commit source changes before recording a candidate' unless changed.empty? && untracked.empty?
    development_identity.merge('revision' => capture('git', '-C', @root, 'rev-parse', 'HEAD'),
                               'dirty' => false)
  end

  def development_identity
    root = capture('git', 'rev-parse', '--show-toplevel')
    config = File.read(File.join(root, 'Config/Version.xcconfig'))
    version = config[/^MARKETING_VERSION = (\d+\.\d+\.\d+)$/, 1]
    build = config[/^CURRENT_PROJECT_VERSION = (\d+)$/, 1]
    raise 'Invalid shared version configuration' unless version && build
    { 'version' => version, 'build' => build_number(build).to_s }
  end

  def build_number(value)
    raise 'Build numbers must be decimal integers from 1 through 9999' unless /\A[1-9]\d{0,3}\z/.match?(value.to_s)
    value.to_i
  end

  def read_json(path)
    JSON.parse(File.read(path))
  end

  def write_json(path, data)
    temporary = "#{path}.#{SecureRandom.hex(8)}.tmp"
    File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
      file.write(JSON.pretty_generate(data) + "\n")
      file.flush
      file.fsync
    end
    File.rename(temporary, path)
    File.open(File.dirname(path), File::RDONLY) { |directory| directory.fsync }
  ensure
    File.unlink(temporary) if temporary && File.exist?(temporary)
  end

  def protect_source(path)
    root = File.realpath(capture('git', 'rev-parse', '--show-toplevel'))
    # Resolve existing ancestors so a symlink cannot hide output in source.
    parent = path
    parent = File.dirname(parent) until File.exist?(parent)
    resolved = File.expand_path(path.delete_prefix(parent + '/'), File.realpath(parent))
    resolved = File.realpath(path) if File.exist?(path)
    return unless resolved == root || resolved.start_with?(root + '/')
    _, status = Open3.capture2e('git', '-C', root, 'check-ignore', '-q', '--', resolved)
    raise 'Output inside the source checkout must be ignored by Git' unless status.success?
  end

  def candidate_identity(directory)
    candidate = read_json(File.join(directory, 'release.json'))
    unless candidate['schema'] == 1 && [true, false].include?(candidate['dirty']) &&
           (!candidate['dirty'] || candidate['source_patch'].is_a?(String)) &&
           /\A[0-9a-f]{40,64}\z/.match?(candidate['revision'].to_s) &&
           /\A\d+\.\d+\.\d+\z/.match?(candidate['version'].to_s) &&
           (['Shared configuration', 'Folio scheme'].include?(candidate['numbering']) || candidate['ledger_id'].is_a?(String))
      raise 'Invalid candidate identity'
    end
    build_number(candidate.fetch('build'))
    candidate
  end

  def verify
    products = File.expand_path(option('products'))
    identity = @options['candidate'] ? candidate_identity(option('candidate')) : development_identity
    expected = SuiteProducts::BUNDLES + SuiteProducts::SERVICES
    expected.each do |bundle|
      raise "Missing shipping bundle: #{bundle}" unless File.directory?(File.join(products, bundle))
    end
    nested = expected.flat_map { |bundle| Dir.glob(File.join(products, bundle, '**/*.{app,framework,xpc}')) }
    bundles = (expected + nested.map { |path| path.delete_prefix(products + '/') }).uniq
    shipping_names = expected.map { |bundle| File.basename(bundle) }
    bundles.each do |bundle|
      relative = bundle.end_with?('.framework') ? 'Resources/Info.plist' : 'Contents/Info.plist'
      plist = JSON.parse(capture('plutil', '-convert', 'json', '-o', '-', File.join(products, bundle, relative)))
      next unless shipping_names.include?(File.basename(bundle)) || plist.fetch('CFBundleIdentifier', '').start_with?('dev.foliosuite.')
      name = File.basename(bundle).sub(/\.(app|framework|xpc)$/, '')
      raise "Unexpected bundle identifier in #{bundle}" unless plist['CFBundleIdentifier'] == "dev.foliosuite.#{name}"
      unless plist['CFBundleShortVersionString'] == identity['version'] && plist['CFBundleVersion'] == identity['build']
        raise "#{bundle}: expected #{identity['version']} (#{identity['build']}), found #{plist['CFBundleShortVersionString']} (#{plist['CFBundleVersion']})"
      end
    end
    puts "Suite identity verified: #{identity['version']} (#{identity['build']}) across shipping bundles and embedded copies"
  end

  def build
    before = source_identity
    directory = File.expand_path(option('candidate'))
    protect_source(directory)
    raise 'Use a new candidate directory for each Folio build' if File.exist?(directory)
    configuration = @options.fetch('configuration', 'Release')
    action = @options.fetch('action', 'build')
    raise 'Configuration must be Debug or Release' unless %w[Debug Release].include?(configuration)
    raise 'Action must be build or build-for-testing' unless %w[build build-for-testing].include?(action)
    derived = File.join(directory, 'DerivedData')
    command = ['xcodebuild', '-workspace', File.join(@root, 'Folio.xcworkspace'),
               '-scheme', 'Folio', '-configuration', configuration, '-destination', 'platform=macOS',
               '-derivedDataPath', derived, action]
    raise 'Xcode build failed' unless system(*command)
    after = source_identity
    raise 'Source changed during the build' unless after == before
    @options['products'] = File.join(derived, 'Build/Products', configuration)
    # Verify the shared identity, not a previous candidate override.
    @options.delete('candidate')
    verify
    write_json(File.join(directory, 'release.json'), after.merge(
      'schema' => 1, 'numbering' => 'Shared configuration', 'prepared_at' => Time.now.utc.iso8601))
    write_json(File.join(directory, "build-#{configuration}.json"),
               { 'identity' => after, 'configuration' => configuration,
                 'xcode' => capture('xcodebuild', '-version'), 'command' => command,
                 'products' => @options['products'], 'verified_at' => Time.now.utc.iso8601 })
  end

  def prepare
    identity = source_identity
    output = File.expand_path(option('output'))
    protect_source(output)
    raise 'Candidate directory already exists; retain it and choose a new directory' if File.exist?(output)
    verify
    raise 'Source changed during candidate preparation' unless source_identity == identity
    FileUtils.mkdir_p(output)
    write_json(File.join(output, 'release.json'), identity.merge(
      'schema' => 1, 'numbering' => 'Shared configuration', 'prepared_at' => Time.now.utc.iso8601))
    puts "Recorded #{identity['version']} (#{identity['build']}) at #{output}; build number unchanged"
  end
end

begin
  SuiteRelease.new(ARGV).run
rescue StandardError => error
  warn "Release: #{error.message}"
  exit 1
end

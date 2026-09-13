#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'json'
require 'fileutils'
require 'open3'
require 'optparse'
require 'securerandom'
require 'time'

# Public entry point for coordinated Suite release preparation and validation.
class SuiteRelease
  def initialize(arguments)
    @command = arguments.shift
    @options = {}
    OptionParser.new do |parser|
      parser.banner = 'Usage: ruby scripts/release.rb init-ledger|prepare|build|verify [options]'
      %w[ledger last-build output products candidate configuration action].each do |name|
        parser.on("--#{name} VALUE") { |value| @options[name] = value }
      end
    end.parse!(arguments)
    raise 'Unexpected positional arguments' unless arguments.empty?
  end

  def run
    case @command
    when 'init-ledger' then initialize_ledger
    when 'prepare' then prepare
    when 'verify' then verify
    when 'build' then build
    else raise 'Expected init-ledger, prepare, build, or verify'
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
    raise 'Source is dirty; commit or remove source changes before preparing a candidate' unless capture('git', '-C', @root, 'status', '--porcelain', '--untracked-files=all').empty?
    settings = development_identity
    settings.merge('revision' => capture('git', '-C', @root, 'rev-parse', 'HEAD'), 'dirty' => false)
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

  def initialize_ledger
    path = File.expand_path(option('ledger'))
    protect_source(path)
    protect_source(path + '.lock')
    last = build_number(option('last-build'))
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path + '.lock', File::RDWR | File::CREAT, 0600) do |lock|
      lock.flock(File::LOCK_EX)
      raise 'Ledger already exists; it must never be reset' if File.exist?(path)
      write_json(path, { 'schema' => 1, 'id' => SecureRandom.uuid, 'last_build' => last })
    end
    puts "Initialized build ledger at #{path}, last reserved build #{last}"
  end

  def candidate_identity(directory)
    candidate = read_json(File.join(directory, 'release.json'))
    unless candidate['schema'] == 1 && candidate['dirty'] == false &&
           /\A[0-9a-f]{40,64}\z/.match?(candidate['revision'].to_s) &&
           /\A\d+\.\d+\.\d+\z/.match?(candidate['version'].to_s) &&
           candidate['ledger_id'].is_a?(String)
      raise 'Invalid candidate identity'
    end
    build_number(candidate.fetch('build'))
    candidate
  end

  def verify
    products = File.expand_path(option('products'))
    identity = @options['candidate'] ? candidate_identity(option('candidate')) : development_identity
    expected = %w[Write.app Research.app Composer.app FolioKit.framework WriteKit.framework ResearchKit.framework ComposerKit.framework]
    expected += %w[Write Research Composer].map { |app| "#{app}.app/Contents/XPCServices/#{app}XPCService.xpc" }
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
    identity = source_identity
    directory = File.expand_path(option('candidate'))
    candidate = candidate_identity(directory)
    raise 'Checkout differs from the prepared candidate revision' unless candidate['revision'] == identity['revision'] && candidate['version'] == identity['version']
    protect_source(directory)
    configuration = @options.fetch('configuration', 'Release')
    action = @options.fetch('action', 'build')
    raise 'Configuration must be Debug or Release' unless %w[Debug Release].include?(configuration)
    raise 'Action must be build or build-for-testing' unless %w[build build-for-testing].include?(action)
    derived = File.join(directory, 'DerivedData')
    command = ['xcodebuild', '-workspace', File.join(@root, 'Folio.xcworkspace'),
               '-scheme', 'Folio', '-configuration', configuration, '-destination', 'platform=macOS',
               '-derivedDataPath', derived, "MARKETING_VERSION=#{candidate['version']}",
               "CURRENT_PROJECT_VERSION=#{candidate['build']}", action]
    report = File.join(directory, "build-#{configuration}.json")
    File.unlink(report) if File.exist?(report)
    raise 'Xcode build failed' unless system(*command)
    raise 'Source changed during the build' unless source_identity == identity
    @options['products'] = File.join(derived, 'Build/Products', configuration)
    verify
    write_json(report,
               { 'identity' => candidate, 'configuration' => configuration,
                 'xcode' => capture('xcodebuild', '-version'), 'command' => command,
                 'products' => @options['products'], 'verified_at' => Time.now.utc.iso8601 })
  end

  def prepare
    identity = source_identity
    output = File.expand_path(option('output'))
    ledger_path = File.expand_path(option('ledger'))
    protect_source(output)
    protect_source(ledger_path)
    protect_source(ledger_path + '.lock')
    raise 'Initialize the shared ledger first with init-ledger' unless File.file?(ledger_path)
    File.open(ledger_path + '.lock', File::RDWR | File::CREAT, 0600) do |lock|
      lock.flock(File::LOCK_EX)
      ledger = read_json(ledger_path)
      raise 'Invalid build ledger' unless ledger['schema'] == 1 && ledger['id'].is_a?(String)
      last = build_number(ledger.fetch('last_build'))
      manifest = File.join(output, 'release.json')
      if File.exist?(output)
        candidate = candidate_identity(output)
        raise 'Ledger is behind this candidate; restore the complete reservation history' if build_number(candidate['build']) > last
        raise 'Candidate belongs to different source or ledger' unless candidate['revision'] == identity['revision'] && candidate['version'] == identity['version'] && candidate['ledger_id'] == ledger['id']
        puts "Reusing #{candidate['version']} (#{candidate['build']}) at #{output}"
        return
      end
      number = build_number([last, identity['build'].to_i].max + 1)
      ledger['last_build'] = number
      # Reserve before writing a candidate. A failed preparation leaves a gap,
      # never a reusable number. All checkouts must share this ledger authority.
      write_json(ledger_path, ledger)
      FileUtils.mkdir_p(output)
      candidate = identity.merge(
        'schema' => 1, 'build' => number.to_s, 'ledger_id' => ledger['id'],
        'prepared_at' => Time.now.utc.iso8601)
      raise 'Source changed during preparation' unless source_identity == identity
      write_json(manifest, candidate)
      puts "Prepared #{candidate['version']} (#{candidate['build']}) at #{output}"
    end
  end
end

begin
  SuiteRelease.new(ARGV).run
rescue StandardError => error
  warn "Release: #{error.message}"
  exit 1
end

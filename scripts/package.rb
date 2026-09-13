#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT
require 'json'
require 'optparse'
require 'open3'
require 'fileutils'
require 'digest'
require_relative 'suite-products'

# Packages an explicitly recorded build; never invokes Installer.
class SuitePackage
  def initialize(arguments)
    @options = {}
    OptionParser.new do |parser|
      %w[candidate products output].each do |name|
        parser.on("--#{name} PATH") { |path| @options[name] = File.expand_path(path) }
      end
    end.parse!(arguments)
    raise 'Unexpected positional arguments' unless arguments.empty?
  end

  def run_command(*arguments)
    stdout, stderr, status = Open3.capture3(*arguments)
    raise "#{arguments.first}: #{stdout}#{stderr}" unless status.success?
    stdout
  end

  def run
    candidate, products, output = %w[candidate products output].map { |name| @options.fetch(name) }
    identity = JSON.parse(File.read(File.join(candidate, 'release.json')))
    run_command('ruby', File.join(__dir__, 'release.rb'), 'verify', '--candidate', candidate, '--products', products)
    raise 'Output already exists; choose a new directory' if File.exist?(output)
    ancestor = File.dirname(output)
    ancestor = File.dirname(ancestor) until File.directory?(ancestor)
    resolved_output = File.join(File.realpath(ancestor), output.delete_prefix(ancestor + '/'))
    [products, candidate].each do |input|
      resolved_input = File.realpath(input)
      raise 'Output must be outside candidate and products' if resolved_output.start_with?(resolved_input + '/')
    end
    bundles = SuiteProducts::BUNDLES
    bundles.each do |bundle|
      embedded = Dir.glob(File.join(products, bundle, '**', '*.framework'))
      raise "Embedded framework in #{bundle}; build the installed Suite configuration" unless embedded.empty?
      unwanted = Dir.glob(File.join(products, bundle, '**', '*')).find { |path| path.end_with?('.dylib', '.xctest', '.dSYM') }
      raise "Unexpected development product: #{unwanted}" if unwanted
    end
    shipping = bundles + SuiteProducts::SERVICES
    shipping.each do |bundle|
      framework = bundle.end_with?('.framework')
      plist = File.join(products, bundle, framework ? 'Resources/Info.plist' : 'Contents/Info.plist')
      metadata = JSON.parse(run_command('/usr/bin/plutil', '-convert', 'json', '-o', '-', plist))
      name = metadata.fetch('CFBundleExecutable')
      raise "Invalid executable name in #{bundle}" unless File.basename(name) == name && !%w[. ..].include?(name)
      executable = File.join(products, bundle, framework ? name : "Contents/MacOS/#{name}")
      raise "Missing executable: #{bundle}" unless File.file?(executable) && File.executable?(executable)
      run_command('/usr/bin/otool', '-L', executable)
    end
    SuiteProducts::REQUIRED_RESOURCES.each do |resource|
      raise "Missing required resource: #{resource}" unless File.file?(File.join(products, resource))
    end
    FileUtils.mkdir_p(output)
    root = File.join(output, 'payload')
    bundles.each do |bundle|
      parent = File.join(root, bundle.end_with?('.app') ? 'Applications/Folio' : 'Library/Frameworks')
      FileUtils.mkdir_p(parent)
      run_command('/usr/bin/ditto', '--noqtn', File.join(products, bundle), File.join(parent, bundle))
    end
    paths = Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).reject { |path| %w[. ..].include?(File.basename(path)) }.sort
    inventory = paths.map do |path|
      stat = File.lstat(path)
      relative = path.delete_prefix(root + '/')
      if stat.symlink?
        target = File.readlink(path)
        resolved = File.realpath(path)
        raise "Payload symlink escapes staging: #{relative}" unless resolved.start_with?(root + '/')
        { 'path' => relative, 'symlink' => target }
      else
        mode = stat.directory? || stat.executable? ? 0755 : 0644
        File.chmod(mode, path)
        entry = { 'path' => relative, 'mode' => format('%04o', mode), 'owner' => 'root:wheel' }
        entry['sha256'] = Digest::SHA256.file(path).hexdigest if stat.file?
        entry
      end
    end
    components = File.join(output, 'components.plist')
    run_command('/usr/bin/pkgbuild', '--analyze', '--root', root, components)
    data = JSON.parse(run_command('/usr/bin/plutil', '-convert', 'json', '-o', '-', components))
    configure = lambda do |entries|
      entries.each do |entry|
        entry['BundleIsRelocatable'] = false
        configure.call(entry['ChildBundles'] || [])
      end
    end
    configure.call(data)
    File.write(components, JSON.generate(data))
    run_command('/usr/bin/plutil', '-convert', 'xml1', components)
    version = "#{identity.fetch('version')}.#{identity.fetch('build')}"
    package = File.join(output, "Folio-#{version}.pkg")
    args = ['/usr/bin/pkgbuild', '--root', root, '--component-plist', components,
      '--identifier', 'dev.foliosuite.Suite', '--version', version,
      '--install-location', '/', '--ownership', 'recommended', package]
    run_command(*args)
    manifest = { 'schema' => 1, 'identity' => identity, 'receipt' => 'dev.foliosuite.Suite',
      'package_version' => version, 'package_sha256' => Digest::SHA256.file(package).hexdigest,
      'command' => args, 'host' => run_command('/usr/bin/sw_vers'), 'ruby' => RUBY_DESCRIPTION,
      'xcode' => run_command('/usr/bin/xcodebuild', '-version'),
      'inventory' => inventory }
    File.write(File.join(output, 'package.json'), JSON.pretty_generate(manifest) + "\n")
    puts package
  end
end

begin
  SuitePackage.new(ARGV).run
rescue StandardError => error
  warn "Package: #{error.message}"
  exit 1
end

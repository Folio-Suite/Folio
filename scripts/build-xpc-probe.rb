#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'json'
require 'optparse'
require 'open3'
require 'digest'

options = {}
OptionParser.new do |parser|
  parser.banner = 'Usage: ruby scripts/build-xpc-probe.rb --products PATH --output PATH --identity SIGNING_IDENTITY'
  %w[products output identity].each { |key| parser.on("--#{key} VALUE") { |value| options[key] = value } }
end.parse!
abort 'Unexpected arguments' unless ARGV.empty?
%w[products output identity].each { |key| abort "Missing --#{key}" unless options[key] }
root = File.expand_path('..', __dir__)
products = File.expand_path(options.fetch('products'))
output = File.expand_path(options.fetch('output'))
abort 'Choose a new output directory' if File.exist?(output)

def run(*args)
  stdout, stderr, status = Open3.capture3(*args)
  abort "#{args.first} failed: #{stdout}#{stderr}" unless status.success?
  stdout
end

names = %w[Write Research Composer]
services = names.map { |name| File.join(products, "#{name}.app/Contents/XPCServices/#{name}XPCService.xpc") }
services.each do |path|
  abort "Missing service: #{path}" unless File.directory?(path)
  run('codesign', '--verify', '--strict', path)
end
app = File.join(output, 'FolioXPCProbe.app')
contents = File.join(app, 'Contents')
FileUtils.mkdir_p(File.join(contents, 'MacOS'))
FileUtils.mkdir_p(File.join(contents, 'XPCServices'))
plist = { 'CFBundleIdentifier' => 'dev.foliosuite.tests.XPCProbe', 'CFBundleExecutable' => 'FolioXPCProbe',
          'CFBundleName' => 'Folio XPC Probe', 'CFBundlePackageType' => 'APPL',
          'CFBundleVersion' => '1', 'LSMinimumSystemVersion' => '14.0', 'LSBackgroundOnly' => true }
File.write(File.join(contents, 'Info.plist'), JSON.generate(plist))
run('plutil', '-convert', 'xml1', File.join(contents, 'Info.plist'))
services.each { |path| run('ditto', '--noqtn', path, File.join(contents, 'XPCServices', File.basename(path))) }
run('xcrun', '--sdk', 'macosx', 'clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
    '-mmacosx-version-min=14.0', '-arch', 'arm64', '-arch', 'x86_64', '-framework', 'Foundation',
    File.join(__dir__, 'xpc-probe/main.m'), '-o', File.join(contents, 'MacOS/FolioXPCProbe'))
run('codesign', '--force', '--options', 'runtime', '--sign', options.fetch('identity'), app)
run('codesign', '--verify', '--deep', '--strict', app)
files = Dir.glob(File.join(app, '**', '*')).select { |path| File.file?(path) && !File.symlink?(path) }
File.write(File.join(output, 'probe.json'), JSON.pretty_generate({
  'base_revision' => run('git', '-C', root, 'rev-parse', 'HEAD').strip,
  'source_diff_sha256' => Digest::SHA256.hexdigest(run('git', '-C', root, 'diff', 'HEAD')),
  'probe_source_sha256' => Digest::SHA256.file(File.join(__dir__, 'xpc-probe/main.m')).hexdigest,
  'builder_sha256' => Digest::SHA256.file(__FILE__).hexdigest,
  'products' => products,
  'files' => files.to_h { |path| [path.delete_prefix(output + '/'), Digest::SHA256.file(path).hexdigest] }
}) + "\n")
puts app

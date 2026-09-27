#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'json'
require 'digest'
require 'open3'

# Throwaway native typography experiment; no application targets are changed.
root = File.expand_path(__dir__)
output = File.expand_path(ARGV.shift || File.join(root, 'build', 'results'))
abort 'Usage: ruby run.rb [output-directory]' unless ARGV.empty?
FileUtils.mkdir_p(output)
binary = File.join(output, 'paragraph-composition')
def run!(*command)
  abort "Command failed: #{command.join(' ')}" unless system(*command)
end
run!('sh', File.join(root, 'fonts', 'fetch-fonts.sh'))
run!('xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra', '-framework', 'AppKit',
     '-framework', 'CoreText', File.join(root, 'main.m'), '-o', binary)
fixtures = File.join(root, 'fixtures', 'specimens.json')
run!(binary, '--fixtures', fixtures, '--output', File.join(output, 'times'), '--font', 'Times-Roman')
font_runs = []
Dir.glob(File.join(root, 'fonts', '.build', 'inputs', '*.otf')).sort.each do |font|
  label = File.basename(font, '.otf')
  run!(binary, '--fixtures', fixtures, '--output', File.join(output, label), '--font-file', font)
  font_runs << { path: font.delete_prefix(root + '/'), sha256: Digest::SHA256.file(font).hexdigest }
end
metadata = {
  fixture_sha256: Digest::SHA256.file(fixtures).hexdigest,
  source_sha256: Digest::SHA256.file(File.join(root, 'main.m')).hexdigest,
  fonts: font_runs,
  xcode: Open3.capture2('xcodebuild', '-version').first.strip,
  sdk: Open3.capture2('xcrun', '--show-sdk-version').first.strip,
  os: Open3.capture2('sw_vers').first.strip
}
File.write(File.join(output, 'run.json'), JSON.pretty_generate(metadata) + "\n")
run!(RbConfig.ruby, File.join(root, 'report.rb'), output)
puts "Native results: #{output}"

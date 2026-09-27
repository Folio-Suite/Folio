#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'fileutils'
require 'json'
require 'digest'
require 'open3'

root = File.expand_path(__dir__)
output = File.expand_path(ARGV.shift || File.join(root, 'build'))
abort 'Usage: ruby Controls/run.rb [output-directory]' unless ARGV.empty?
FileUtils.mkdir_p(output)
sources = {}
results = {}
%w[textkit coretext].each do |engine|
  source = File.join(root, "#{engine}.m")
  binary = File.join(output, "#{engine}-controls")
  command = ['xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'AppKit',
             '-framework', 'CoreText', source, '-o', binary]
  abort "Compilation failed: #{engine}" unless system(*command)
  destination = File.join(output, engine)
  abort "Control probe failed: #{engine}" unless system(binary, '--output', destination)
  result_path = File.join(destination, 'results.json')
  result = JSON.parse(File.read(result_path))
  abort "No control results: #{engine}" if result.fetch('cases').empty?
  if engine == 'textkit'
    cases = result.fetch('cases')
    abort 'Incomplete TextKit 2 source coverage' unless cases.all? { |item| item.fetch('actual').fetch('completeRangeCoverage') }
    unmet = cases.count { |item| !item.fetch('contract').fetch('pass') }
    puts "TextKit 2: #{cases.length} cases, #{unmet} unmet capability contracts (see results)"
  end
  sources["#{engine}.m"] = Digest::SHA256.file(source).hexdigest
  results["#{engine}-results.json"] = Digest::SHA256.file(result_path).hexdigest
end
metadata = {
  source_sha256: sources,
  result_sha256: results,
  xcode: Open3.capture2('xcodebuild', '-version').first.strip,
  sdk: Open3.capture2('xcrun', '--show-sdk-version').first.strip,
  os: Open3.capture2('sw_vers').first.strip
}
File.write(File.join(output, 'run.json'), JSON.pretty_generate(metadata) + "\n")
puts "Control evidence: #{output}"

#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'json'
require 'open3'
require_relative 'suite-products'

products = File.expand_path(ARGV.fetch(0))
bundles = (SuiteProducts::BUNDLES + SuiteProducts::SERVICES).map { |name| File.join(products, name) }
bundles.select! { |path| File.directory?(path) }
abort 'No shipping apps found for signing validation' unless bundles.any? { |path| path.end_with?('.app') }
teams = []
bundles.each do |bundle|
  output, status = Open3.capture2e('codesign', '--verify', '--deep', '--strict', bundle)
  abort output unless status.success?
  details, status = Open3.capture2e('codesign', '-d', '--verbose=4', bundle)
  abort details unless status.success?
  team = details[/^TeamIdentifier=([A-Z0-9]{10})$/, 1]
  abort "Missing team signature: #{bundle}" unless team
  teams << team
  next if bundle.end_with?('.framework')
  abort "Hardened Runtime is missing: #{bundle}" unless details.match?(/flags=.*\bruntime\b/)
  xml, errors, status = Open3.capture3('codesign', '-d', '--entitlements', '-', '--xml', bundle)
  abort errors unless status.success? && !xml.empty?
  json, errors, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', '--', '-', stdin_data: xml)
  abort errors unless status.success?
  entitlements = JSON.parse(json)
  abort "Library validation is disabled: #{bundle}" if entitlements['com.apple.security.cs.disable-library-validation']
end
abort 'Shipping products have inconsistent Team IDs' unless teams.uniq.length == 1
puts 'Team signatures, Hardened Runtime, and library validation verified.'

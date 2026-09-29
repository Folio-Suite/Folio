#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT
require 'fileutils'
require 'tmpdir'
require 'open3'
Dir.chdir(__dir__)
abort 'Build failed' unless system('xcrun', 'swift', 'build', '-Xswiftc', '-strict-concurrency=complete', '-Xswiftc', '-warnings-as-errors')
Dir.mktmpdir('folio-undokit-interface-fixtures-') do |fixtures|
  executable = File.expand_path('.build/debug/InterfaceConsumer')
  abort 'Writer failed' unless system(executable, 'write', fixtures)
  abort 'Fresh reader failed' unless system(executable, 'read', fixtures)
end

Dir.mktmpdir('folio-undokit-negative-') do |scratch|
  output, status = Open3.capture2e('xcrun', 'swiftc', '-swift-version', '6',
                                  '-strict-concurrency=complete', '-warnings-as-errors',
                                  '-c', 'NegativeFixtures/UnsafeActorCrossing.swift',
                                  '-o', File.join(scratch, 'negative.o'))
  abort "Negative isolation fixture unexpectedly passed" if status.success?
  abort "Negative fixture failed for an unexpected reason:\n#{output}" unless output.include?('risks causing data races')
  puts 'PASS: negative actor-crossing fixture rejected for a data-race risk'
end

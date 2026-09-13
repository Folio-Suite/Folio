#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT
require 'open3'
require 'tempfile'

begin
  phase = ARGV.fetch(0)
  raise 'Expected build phase' unless phase == 'build'
  # Xcode also invokes this pre-build action for Archive (ACTION=install).
  # Allocating here ensures compilation sees the new number in either operation.
  if ENV['ACTION'] == 'clean'
    puts "Folio: skipping build-number allocation for #{ENV['ACTION']} build phase"
    exit 0
  end
  root = File.expand_path('..', __dir__)
  git_dir, diagnostic, status = Open3.capture3('git', '-C', root, 'rev-parse', '--absolute-git-dir')
  raise diagnostic unless status.success?
  path = File.join(root, 'Config/Version.xcconfig')
  File.open(File.join(git_dir.strip, 'folio-build-number.lock'), File::RDWR | File::CREAT, 0600) do |lock|
    lock.flock(File::LOCK_EX)
    source = File.read(path)
    matches = source.scan(/^CURRENT_PROJECT_VERSION = ([1-9]\d{0,3})$/)
    raise 'Expected exactly one build number from 1 through 9999' unless matches.length == 1
    number = matches.first.first.to_i + 1
    raise 'Build number exhausted' if number > 9999
    replacement = source.sub(/^CURRENT_PROJECT_VERSION = \d+$/, "CURRENT_PROJECT_VERSION = #{number}")
    Tempfile.create(['.Version-', '.xcconfig'], File.dirname(path)) do |file|
      file.chmod(File.stat(path).mode & 0777)
      file.write(replacement)
      file.flush
      file.fsync
      File.rename(file.path, path)
      File.open(File.dirname(path), File::RDONLY) { |directory| directory.fsync }
    end
    puts "Folio: #{phase} pre-action advanced Suite build to #{number} (ACTION=#{ENV['ACTION']})"
  end
rescue StandardError => error
  warn "Folio build number: #{error.message}"
  exit 1
end

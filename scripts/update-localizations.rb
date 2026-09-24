#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'json'
require 'open3'
require 'optparse'
require 'rexml/document'
require 'tmpdir'

# Extract each application's and framework's source tree into its owning catalog.
# Requires active Xcode developer tools. Existing translations are preserved.
class LocalizationUpdate
  ROOT = File.expand_path('..', __dir__)
  CODE = %w[FolioKit/FolioKit Write/Write Write/WriteKit Write/WriteXPCService Research/Research Research/ResearchKit Research/ResearchXPCService Composer/Composer Composer/ComposerKit Composer/ComposerXPCService].freeze
  STORYBOARDS = [
    ['Write/Write/Base.lproj/Main.storyboard', 'Write/Write/mul.lproj/Main.xcstrings'],
    ['Research/Research/Base.lproj/Main.storyboard', 'Research/Research/mul.lproj/Main.xcstrings'],
    ['Write/WriteKit/Resources/Base.lproj/Editor.storyboard', 'Write/WriteKit/Resources/mul.lproj/Editor.xcstrings'],
    ['Composer/Composer/Base.lproj/Main.storyboard', 'Composer/Composer/mul.lproj/Main.xcstrings']
  ].freeze

  def source_files(folder)
    Dir.glob("#{folder}/**/*.{h,m,mm}").sort
  end

  def mark_for_review(node)
    return unless node.is_a?(Hash)
    node['stringUnit']['state'] = 'needs_review' if node['stringUnit']
    node.each_value { |value| mark_for_review(value) }
  end

  def read_strings(path)
    output, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', path)
    raise "plutil failed: #{error}" unless status.success?
    JSON.parse(output)
  end

  def refresh(path, values, comments, write)
    original = File.exist?(path) ? File.read(path) : nil
    data = original ? JSON.parse(original) : { 'sourceLanguage' => 'en', 'strings' => {}, 'version' => '1.2' }
    raise "#{path}: expected English source language" unless data['sourceLanguage'] == 'en'
    # genstrings exports plain fallbacks, not the authored plural/device structure.
    # Never silently replace that structure with a single English string.
    structured = values.keys.select do |key|
      source = data['strings'].dig(key, 'localizations', 'en') || {}
      (source.keys - ['stringUnit']).any?
    end
    raise "#{path}: manually review structured source entries: #{structured.join(', ')}" unless structured.empty?
    problems = []
    values.each do |key, value|
      entry = data['strings'][key] || {}
      old = entry.dig('localizations', 'en', 'stringUnit', 'value')
      comment = [comments[key], entry['comment'], "#{key}: user-facing text."].find { |text| text && !text.empty? }
      problems << key if old != value || entry['comment'].to_s.empty? || entry['comment'] != comment || entry['extractionState'] == 'stale'
      next unless write
      if !old.nil? && old != value
        (entry['localizations'] || {}).each do |language, localization|
          mark_for_review(localization) if language != 'en'
        end
      end
      entry['extractionState'] = 'manual'
      entry['comment'] = comment
      entry['localizations'] ||= {}
      entry['localizations']['en'] = { 'stringUnit' => { 'state' => 'translated', 'value' => value } }
      # Keyboard shortcut glyphs must continue to describe the implemented shortcut.
      entry['shouldTranslate'] = false if key.include?('shortcut')
      data['strings'][key] = entry
    end
    stale = data['strings'].keys - values.keys
    problems.concat(stale.sort)
    stale.each { |key| data['strings'][key]['extractionState'] = 'stale' } if write
    if write
      data['strings'] = data['strings'].sort.to_h
      File.write(path, JSON.pretty_generate(data) + "\n") unless original && JSON.parse(original) == data
    elsif !problems.empty?
      raise "#{path.delete_prefix(ROOT + '/')}: refresh/review #{problems.join(', ')}"
    end
    puts "#{path.delete_prefix(ROOT + '/')}: #{values.size} extracted strings"
  end

  def run(arguments)
    write = false
    parser = OptionParser.new do |options|
      options.banner = 'Usage: ruby scripts/update-localizations.rb [--write]'
      options.separator 'Check English catalogs against Objective-C and Interface Builder.'
      options.on('--write', 'Refresh source entries while preserving translations.') { write = true }
    end
    parser.parse!(arguments)
    raise "Unexpected arguments: #{arguments.join(' ')}" unless arguments.empty?
    Dir.mktmpdir('folio-localization-') do |temp|
      CODE.each_with_index do |folder, index|
        output = "#{temp}/#{index}"
        Dir.mkdir(output)
        sources = source_files("#{ROOT}/#{folder}")
        raise 'genstrings failed' unless system('xcrun', 'genstrings', '-q', '-o', output, *sources)
        strings = "#{output}/Localizable.strings"
        values = File.exist?(strings) ? read_strings(strings) : {}
        # Empty service skeletons need no new resource until they contain text.
        next if values.empty? && !File.exist?("#{ROOT}/#{folder}/Localizable.xcstrings")
        comments = {}
        if File.exist?(strings)
          text = File.read(strings, encoding: 'bom|utf-16:utf-8')
          text.scan(%r{/\*\s*(.*?)\s*\*/\s*"([^"\\]+)"\s*=}m).each { |comment, key| comments[key] = comment.strip }
        end
        refresh("#{ROOT}/#{folder}/Localizable.xcstrings", values, comments, write)
      end
      STORYBOARDS.each_with_index do |(storyboard, catalog), index|
        strings = "#{temp}/storyboard-#{index}.strings"
        raise 'ibtool failed' unless system('xcrun', 'ibtool', '--export-strings-file', strings, "#{ROOT}/#{storyboard}")
        objects = {}
        REXML::Document.new(File.read("#{ROOT}/#{storyboard}")).root.each_recursive do |element|
          objects[element.attributes['id']] = element if element.attributes['id']
        end
        comments = {}
        values = read_strings(strings)
        values.each_key do |key|
          identifier, _, property_name = key.partition('.')
          element = objects.fetch(identifier)
          label = element.attributes['userLabel'] || identifier
          titles = []
          ancestor = element.parent
          while ancestor.is_a?(REXML::Element)
            title = ancestor.attributes['title'] || ancestor.attributes['userLabel']
            titles.unshift(title) if title && titles.first != title
            ancestor = ancestor.parent
          end
          location = (titles + [label]).join(' > ')
          comments[key] = "#{location} — #{element.name} #{property_name}: #{values[key].inspect} in #{File.basename(storyboard, '.storyboard')}. Keep Folio domain terms consistent with the glossary."
        end
        refresh("#{ROOT}/#{catalog}", values, comments, write)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    LocalizationUpdate.new.run(ARGV)
  rescue StandardError => error
    warn error.message
    exit 1
  end
end

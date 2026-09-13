#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require_relative '../update-localizations'

class LocalizationsTest < Minitest::Test
  def test_refresh_preserves_translations_and_marks_changes_and_removals
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'Localizable.xcstrings')
      original = {
        'sourceLanguage' => 'en', 'version' => '1.2',
        'strings' => {
          'title' => { 'comment' => 'Existing context', 'localizations' => {
            'en' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Old' } },
            'fr' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'Ancien' } }
          } },
          'removed' => { 'comment' => 'Retain for review' }
        }
      }
      File.write(path, JSON.generate(original))
      updater = LocalizationUpdate.new
      values = { 'title' => 'New — title', 'shortcut.save' => '⌘S' }
      before = File.read(path)
      assert_raises(RuntimeError) { updater.refresh(path, values, {}, false) }
      assert_equal before, File.read(path), 'Check mode must not write'
      capture_io { updater.refresh(path, values, {}, true) }
      strings = JSON.parse(File.read(path)).fetch('strings')
      assert_equal 'New — title', strings.dig('title', 'localizations', 'en', 'stringUnit', 'value')
      assert_equal({ 'state' => 'needs_review', 'value' => 'Ancien' }, strings.dig('title', 'localizations', 'fr', 'stringUnit'))
      assert_equal 'Existing context', strings.dig('title', 'comment')
      assert_equal false, strings.dig('shortcut.save', 'shouldTranslate')
      assert_equal 'stale', strings.dig('removed', 'extractionState')
      assert_raises(RuntimeError) { updater.refresh(path, values, {}, false) }
      updated = JSON.parse(File.read(path))
      updated['strings'].delete('removed')
      File.write(path, JSON.generate(updated))
      capture_io { updater.refresh(path, values, {}, false) }
    end
  end
end

#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require_relative '../update-localizations'

class LocalizationsTest < Minitest::Test
  def test_headers_and_objective_c_plus_plus_are_extracted
    Dir.mktmpdir do |directory|
      %w[Labels.h Model.m Adapter.mm Ignored.txt].each { |name| File.write(File.join(directory, name), '') }
      assert_equal %w[Adapter.mm Labels.h Model.m], LocalizationUpdate.new.source_files(directory).map { |path| File.basename(path) }
    end
  end

  def test_changed_context_is_detected_without_changing_translation
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'Localizable.xcstrings')
      updater = LocalizationUpdate.new
      capture_io { updater.refresh(path, { 'title' => 'Title' }, { 'title' => 'Old context' }, true) }
      before = File.read(path)
      assert_raises(RuntimeError) { updater.refresh(path, { 'title' => 'Title' }, { 'title' => 'Specific context' }, false) }
      assert_equal before, File.read(path)
      capture_io { updater.refresh(path, { 'title' => 'Title' }, { 'title' => 'Specific context' }, true) }
      assert_equal 'Specific context', JSON.parse(File.read(path)).dig('strings', 'title', 'comment')
    end
  end

  def test_plural_source_is_never_flattened_and_translation_variants_need_review
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'Localizable.xcstrings')
      plural = { 'variations' => { 'plural' => {
        'one' => { 'stringUnit' => { 'state' => 'translated', 'value' => 'One item' } },
        'other' => { 'stringUnit' => { 'state' => 'translated', 'value' => '%lld items' } }
      } } }
      data = { 'sourceLanguage' => 'en', 'strings' => { 'count' => {
        'comment' => 'Item count', 'localizations' => { 'en' => plural }
      } }, 'version' => '1.2' }
      File.write(path, JSON.generate(data))
      updater = LocalizationUpdate.new
      before = File.read(path)
      assert_raises(RuntimeError) { updater.refresh(path, { 'count' => '%lld items' }, {}, true) }
      assert_equal before, File.read(path)
      updater.mark_for_review(plural)
      assert_equal %w[needs_review needs_review], plural['variations']['plural'].values.map { |v| v['stringUnit']['state'] }
    end
  end

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

# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'

# Exercises the same executable and JSON files used by the comparison runner.
class ParagraphCompositionCLITest < Minitest::Test
  def setup
    @temporary = Dir.mktmpdir('folio-paragraph-test-')
    @binary = ENV.fetch('PARAGRAPH_COMPOSITION_BINARY')
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  def invoke(fixture, name = 'output')
    path = File.join(@temporary, "#{name}-fixture.json")
    File.write(path, JSON.generate(fixture))
    output = File.join(@temporary, name)
    stdout, stderr, status = Open3.capture3(@binary, '--fixtures', path, '--output', output,
                                          '--font', 'Times-Roman')
    [output, stdout, stderr, status]
  end

  def test_empty_specimen_list_is_rejected
    output, _stdout, stderr, status = invoke('specimens' => [])
    refute status.success?, 'An empty experiment must fail rather than report success'
    refute File.exist?(File.join(output, 'results.json'))
    refute_empty stderr
  end

  def test_duplicate_ids_cannot_overwrite_comparison_images
    specimen = { 'id' => 'same', 'language' => 'en', 'text' => 'A complete sentence.',
                 'source' => 'test fixture', 'locator' => 'test' }
    output, _stdout, _stderr, status = invoke('specimens' => [specimen, specimen])
    refute status.success?, 'Duplicate specimen IDs would overwrite image evidence'
    refute File.exist?(File.join(output, 'results.json'))
  end

  def test_complete_unicode_paragraph_has_repeatable_breaks
    text = ('An author compares café typography, scholarly references, and a symbol 𝄞 across complete lines. ' * 8).strip
    fixture = { 'specimens' => [{ 'id' => 'coverage', 'language' => 'en', 'text' => text,
                                 'source' => 'authored test fixture', 'locator' => 'test' }] }
    first_output, _stdout, stderr, status = invoke(fixture, 'first')
    assert status.success?, stderr
    first = JSON.parse(File.read(File.join(first_output, 'results.json')))
    assert_equal 12, first.fetch('cases').length
    first.fetch('cases').each do |item|
      assert item.fetch('coverage').fetch('complete'), item.inspect
      assert_equal text, item.fetch('lines').map { |line| line.fetch('text') }.join
      assert_equal text.encode('UTF-16LE').bytesize / 2, item.fetch('lines').last.fetch('breakUTF16')
      assert_operator item.fetch('lines').length, :>, 1
      image = File.binread(File.join(first_output, item.fetch('image')))
      assert_equal "\x89PNG\r\n\x1a\n".b, image.byteslice(0, 8)
      item.fetch('lines').each do |line|
        bounds = line.fetch('typographicBounds')
        assert_operator bounds.fetch('height'), :>, 0
        assert_operator bounds.fetch('width'), :<=, item.fetch('measurePoints') + 12
      end
    end
    second_output, _stdout, stderr, status = invoke(fixture, 'second')
    assert status.success?, stderr
    second = JSON.parse(File.read(File.join(second_output, 'results.json')))
    stable = lambda do |results|
      results.fetch('cases').map do |item|
        [item.fetch('engine'), item.fetch('measurePoints'), item.fetch('requestedHyphenation'),
         item.fetch('lines').map { |line| [line.fetch('range'), line.fetch('text'), line.fetch('breakUTF16')] }]
      end
    end
    assert_equal stable.call(first), stable.call(second)
  end

  def test_empty_identifier_is_rejected
    output, _stdout, _stderr, status = invoke('specimens' => [
      { 'id' => '', 'language' => 'en', 'text' => 'A complete sentence.' }
    ])
    refute status.success?, 'A specimen needs an identifier for comparison'
    refute File.exist?(File.join(output, 'results.json'))
  end
end

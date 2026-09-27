#!/usr/bin/env ruby
# frozen_string_literal: true
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'fileutils'

root = File.expand_path('..', __dir__)
art = File.join(root, 'Design/Icons/Documents')
notice = "SPDX-FileCopyrightText: 2026 the Folio Project\nSPDX-License-Identifier: MIT\n"
Dir.mktmpdir('folio-document-icons') do |temp|
  renderer = File.join(temp, 'render')
  abort 'Renderer compilation failed' unless system('xcrun', 'swiftc', File.join(art, 'render.swift'), '-o', renderer)
  {'Write' => 'Work', 'Research' => 'Library', 'Composer' => 'Edition'}.each do |app, name|
    catalog = File.join(root, app, app, 'Assets.xcassets')
    icons = File.join(catalog, "#{name}Icon.iconset")
    zip_icons = File.join(catalog, "#{name}ZipIcon.iconset")
    FileUtils.mkdir_p([icons, zip_icons])
    # Keep license metadata beside the set, outside the PNG-only iconset.
    File.write("#{icons}.license", notice)
    File.write("#{zip_icons}.license", notice)
    [16, 32, 128, 256, 512].each do |size|
      detail = size <= 32 ? 'Tiny' : size <= 128 ? 'Medium' : 'Large'
      source = File.join(art, "#{name}-Badge-#{detail}.svg")
      optical_source = File.join(art, "#{name}-Badge-#{size}.svg")
      source = optical_source if File.file?(optical_source)
      if size >= 128
        overlay = File.read(File.join(art, 'Zip-detail.svg')).sub(/.*?<svg[^>]*>/m, '').sub(%r{</svg>\s*\z}, '')
        zip_source = File.join(temp, "#{name}-#{size}-zip.svg")
        File.write(zip_source, File.read(source).sub('</svg>', overlay + '</svg>'))
      end
      [1, 2].each do |scale|
        suffix = scale == 2 ? '@2x' : ''
        output = File.join(icons, "icon_#{size}x#{size}#{suffix}.png")
        abort "Rendering failed: #{output}" unless system(renderer, source, output, (size * scale).to_s)
        zip_output = File.join(zip_icons, File.basename(output))
        if size < 128
          FileUtils.cp(output, zip_output)
        else
          abort "Rendering failed: #{zip_output}" unless system(renderer, zip_source, zip_output, (size * scale).to_s)
        end
      end
    end
    puts "Rendered #{name}Icon: ten representations with size-specific artwork"
  end
end

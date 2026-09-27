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
  {'Write' => ['Work', '#C58A30'], 'Research' => ['Library', '#8256B8'], 'Composer' => ['Edition', '#367DC6']}.each do |app, (name, color)|
    catalog = File.join(root, app, app, 'Assets.xcassets')
    icons = File.join(catalog, "#{name}Icon.iconset")
    FileUtils.mkdir_p(icons)
    # Keep license metadata beside the set, outside the PNG-only iconset.
    File.write("#{icons}.license", notice)
    [16, 32, 128, 256, 512].each do |size|
      detail = size <= 32 ? 'Tiny' : size <= 128 ? 'Medium' : 'Large'
      source = File.join(art, "#{name}-Badge-#{detail}.svg")
      optical_source = File.join(art, "#{name}-Badge-#{size}.svg")
      source = optical_source if File.file?(optical_source)
      backgrounds = {}
      [false, true].each do |archive|
        set = File.join(catalog, "#{name}#{archive ? 'Zip' : ''}Background.iconset")
        FileUtils.mkdir_p(set)
        File.write("#{set}.license", notice)
        body = +''
        if size >= 128
          body << %(<defs><linearGradient id="wash" x2="0" y2="1"><stop stop-color="#{color}" stop-opacity="0"/><stop offset=".45" stop-color="#{color}" stop-opacity=".02"/><stop offset="1" stop-color="#{color}" stop-opacity=".22"/></linearGradient></defs><rect width="1024" height="1024" fill="url(#wash)"/>)
        end
        body << %(<rect x="176" width="#{size == 32 ? 48 : 36}" height="1024" fill="#{color}" fill-opacity=".8"/>) if size >= 32
        if archive && size >= 128
          body << File.read(File.join(art, 'Zip-detail.svg')).sub(/.*?<svg[^>]*>/m, '').sub(%r{</svg>\s*\z}, '')
        end
        background = File.join(temp, "#{name}-#{size}-#{archive}-background.svg")
        File.write(background, %(<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">#{body}</svg>))
        backgrounds[set] = background
      end
      [1, 2].each do |scale|
        suffix = scale == 2 ? '@2x' : ''
        output = File.join(icons, "icon_#{size}x#{size}#{suffix}.png")
        abort "Rendering failed: #{output}" unless system(renderer, source, output, (size * scale).to_s)
        backgrounds.each do |set, background|
          destination = File.join(set, File.basename(output))
          abort "Rendering failed: #{destination}" unless system(renderer, background, destination, (size * scale).to_s, '--canvas')
        end
      end
    end
    puts "Rendered #{name}Icon: ten tightly fitted badges and paired transparent backgrounds"
  end
end

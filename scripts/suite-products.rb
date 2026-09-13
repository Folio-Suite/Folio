# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

# Shipping inventory shared by candidate verification and installer staging.
module SuiteProducts
  BUNDLES = %w[Write.app Research.app Composer.app FolioKit.framework WriteKit.framework ResearchKit.framework ComposerKit.framework].freeze
  SERVICES = %w[Write Research Composer].map { |app| "#{app}.app/Contents/XPCServices/#{app}XPCService.xpc" }.freeze
  REQUIRED_RESOURCES = %w[
    Write.app/Contents/Resources/Base.lproj/Main.storyboardc/MainMenu.nib
    Research.app/Contents/Resources/Base.lproj/Main.storyboardc/MainMenu.nib
    Research.app/Contents/Resources/Base.lproj/Main.storyboardc/Document\ Window\ Controller.nib
    Composer.app/Contents/Resources/Base.lproj/Main.storyboardc/MainMenu.nib
    Composer.app/Contents/Resources/Base.lproj/Main.storyboardc/Document\ Window\ Controller.nib
    Research.app/Contents/Resources/FRDocument.momd/FRDocument.mom
    Composer.app/Contents/Resources/Document.momd/Document.mom
    WriteKit.framework/Resources/FWWork.momd/FWWorkV1.mom
    WriteKit.framework/Resources/Base.lproj/Editor.storyboardc/EditorWindow.nib
    WriteKit.framework/Resources/Base.lproj/Editor.storyboardc/Editor.nib
    WriteKit.framework/Resources/Assets.car
  ].freeze
end

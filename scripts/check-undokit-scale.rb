#!/usr/bin/env ruby
# SPDX-FileCopyrightText: 2026 the Folio Project
# SPDX-License-Identifier: MIT

# UndoKit owns its guarded production-scale runner.
runner = File.expand_path('../UndoKit/scripts/check-undokit-scale.rb', __dir__)
abort 'Initialize UndoKit with git submodule update --init --recursive' unless File.file?(runner)
exec RbConfig.ruby, runner, *ARGV

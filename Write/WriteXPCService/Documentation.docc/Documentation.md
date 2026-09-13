# ``WriteXPCService``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

An experimental NSXPCConnection host in the Write project.

## Overview

Write embeds this executable in its XPCServices directory. The current calculator
operation is Xcode template scaffolding. Domain operations and the client adapter
will live in WriteKit, leaving this executable responsible for listener setup.
This skeleton does not establish cross-application Work Session authority.

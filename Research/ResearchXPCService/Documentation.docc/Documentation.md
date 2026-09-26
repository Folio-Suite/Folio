# ``ResearchXPCService``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

The bundled Research service skeleton.

## Overview

Research embeds this per-app NSXPC service. The listener exposes a nonce-echo diagnostic with its process ID for startup
and dependency-loading verification. Future domain operations will use ResearchKit's public
interface. No domain operations or shipping application clients are implemented yet.
The development-only harness is documented in the repository’s installer guide.

This service does not establish shared cross-app authority. Work Session hosting
and service discovery remain separate design work.

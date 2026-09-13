# ``ResearchXPCService``

<!--
SPDX-FileCopyrightText: 2026 the Folio Project
SPDX-License-Identifier: MIT
-->

The bundled Research service skeleton.

## Overview

Research embeds this per-app NSXPC service. The listener and empty transport protocol
reserve a place for future operations implemented through ResearchKit's public
interface. No domain operations or application clients are implemented yet.

This service does not establish shared cross-app authority. Work Session hosting
and service discovery remain separate design work.

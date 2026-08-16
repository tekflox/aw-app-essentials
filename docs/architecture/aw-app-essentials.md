---
repo: architecture
path: docs/architecture/aw-app-essentials.md
source: generated
edited: false
checksum: sha256:1b5887dd14ad82b05a70b757f713e853c658c4a6408e41945a718b6e2805c42f
---
# Essential CLI Tools

- **repo**: aw-app-essentials
- **layer**: app
- **technologies**: python
- **health** (derived): planned

Installs a broad set of workspace CLI tooling and keeps it present across restarts: core networking/utilities (telnet, ping, curl, nc, perl, python, vim, docker), Go, a Node.js dev toolkit (nvm, node, npm, npx, yarn, pnpm), Terraform, and Homebrew (Linuxbrew). Consolidates what used to be four separate apps (essentials, node, terraform, brew) into one, since they're all the same kind of thing: pure command installs, no login/settings/secrets.

## Connections
_none_

## MCP tools
_none exposed_

## Requirements
_none documented_

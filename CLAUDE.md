# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an automated development environment setup tool for WSL Ubuntu 24.04. The project consists of a single main bash script (`setup.sh`) that installs and configures a comprehensive development environment.

## Key Commands

### Running the Setup
```bash
./setup.sh
```
The script is idempotent and can be safely run multiple times.

### Testing Changes
Since this is a bash script project, test changes by:
1. Running the script in a fresh WSL Ubuntu 24.04 instance
2. Verifying each tool installation with its version command (e.g., `node --version`, `pnpm --version`)
3. Checking that bash completions and aliases work correctly

## Architecture & Key Concepts

### Script Design Principles
- **Idempotent**: All operations check for existing configurations before applying changes
- **Section-based .bashrc management**: Uses `# --- START <section> ---` and `# --- END <section> ---` markers to prevent duplication
- **Backup safety**: Creates `.bashrc.backup` before modifications

### Main Components in setup.sh

1. **System Package Installation** (lines ~10-30)
   - Uses `apt-get` to install base development tools
   - Checks for sudo permissions

2. **Bash Configuration Enhancement** (lines ~35-75)
   - Enables advanced bash completion features
   - Sets up case-insensitive completion and colored stats

3. **Tool Installations** (lines ~80-end)
   - Each tool follows pattern: check if exists → install → configure → add to PATH
   - Tools include: Starship, NVM/Node.js, Claude Code, GitHub CLI, Azure CLI, AWS CLI, Cloudflare CLI

4. **Alias Configuration** (embedded in .bashrc sections)
   - Podman/Docker compatibility aliases
   - Common developer shortcuts (p=pnpm, g=git, etc.)

### Claude Code MCP Integration

The project includes MCP server configurations in `.claude.mcp.json` for:
- **filesystem**: Access to ~/repos directory
- **convex**: Database integration (requires project-specific setup)
- **strapi**: CMS integration (requires URL/token in `.mcp/strapi-mcp-server.config.json`)
- **memory**: Knowledge graph capabilities

When modifying MCP configurations:
1. Edit `.claude.mcp.json` for server definitions
2. Update `.mcp/*.config.json` files for server-specific settings
3. Test with `mcp-client list` to verify configurations

## Development Notes

- The script sources `.bashrc` after modifications to immediately apply changes
- All PATH modifications are added to `.bashrc` for persistence
- Tool installations use official installation methods (curl scripts, official CLIs)
- The `~/repos` directory is created as the default workspace location
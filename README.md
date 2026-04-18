# Ubuntu Dev Environment Setup

Automated, idempotent setup of an Ubuntu development environment. Works on both **WSL** (Windows Subsystem for Linux) and **native Ubuntu Desktop**, with extra steps for **Microsoft Surface** devices when detected.

## Usage

```sh
git clone https://github.com/cpontet/ubuntu-setup.git
cd ubuntu-setup
chmod +x setup.sh
./setup.sh
```

The script is safe to re-run — it detects what's already installed and only applies missing pieces. A one-time backup of `~/.bashrc` is saved to `~/.bashrc.backup.original`.

## What gets installed

### Common (both WSL and native Desktop)

**System packages**
- `git`, `curl`, `wget`, `unzip`, `jq`, `tree`, `htop`, `neofetch`
- `build-essential`, `python3-pip`, `python3-venv`
- `bash-completion`, `command-not-found`

**Containers**
- Podman + podman-compose (with `docker` alias pointing to `podman`)

**Shell experience**
- Starship prompt
- Nerd Fonts: FiraCode, JetBrainsMono, Meslo, Hack
- Enhanced bash completion (case-insensitive, colored, menu-complete via Tab)
- History tuning (10k lines, dedup)
- Aliases: `c=clear`, `p=pnpm`, `y=yarn`, `g=git`, `k=kubectl`, `pod=podman`, `docker=podman`, `ll`, `la`, `l`
- `~/repos` workspace directory

**JavaScript / TypeScript**
- NVM + Node.js LTS
- Corepack with pnpm + yarn
- Bun (JavaScript runtime & package manager)
- typescript-language-server (TypeScript LSP for Claude Code)

**Java / JVM**
- SDKMAN (JVM version manager)
- OpenJDK 25 (Temurin, via SDKMAN)
- jdtls 1.57.0 (Eclipse Java LSP for Claude Code)

**Python**
- `uv` (fast Python package manager)

**Cloud / DevOps CLIs**
- GitHub CLI (`gh`)
- GitLab CLI (`glab`)
- Azure CLI (`az`)
- AWS CLI (`aws`)
- Cloudflare Wrangler
- kubectl + k9s
- Helm
- direnv (auto-load `.envrc` per project)

**AI tooling**
- Claude Code (native binary)
- Ollama (local LLMs)

### Native Ubuntu Desktop only

Skipped under WSL.

**Browsers & editor**
- Brave browser
- Microsoft Edge
- Visual Studio Code

**GNOME polish**
- GNOME Tweaks + Extension Manager
- Extensions enabled: Dash to Panel, User Themes, GSConnect
- WhiteSur GTK theme + matching icon theme (macOS-like look)
- GNOME Terminal default font set to `FiraCode Nerd Font Mono 12`

**Apps**
- Flatpak + Flathub
- VLC, GIMP, Evince, GNOME Sound Recorder, GParted
- Shotcut (video editor, via Flatpak)

**System**
- Belgian keyboard layout (applied to console, X11, and LUKS prompt)
- GRUB set to 1920x1080 (readable on HiDPI)
- GRUB vimix theme (1080p)

### Microsoft Surface (auto-detected)

Only runs if `/sys/class/dmi/id` reports a Microsoft Surface device.

- `linux-image-surface` + `linux-headers-surface`
- `intel-microcode`
- `libwacom-surface` (pen/stylus)
- `iptsd` (Intel Precise Touch & Stylus Daemon)
- `linux-surface-secureboot-mok` (if available — allows Secure Boot)

## Manual steps after running the script

### Always

1. **Restart your terminal** (or `source ~/.bashrc`) so new PATH entries, aliases, NVM, SDKMAN, and Bun are loaded.
2. **Verify core tools**:
   ```sh
   claude --version
   gh --version
   glab --version
   node --version
   bun --version
   java --version
   ```
3. **Authenticate the CLIs** you plan to use:
   ```sh
   gh auth login
   glab auth login
   az login
   aws configure
   ```

### Native Desktop only

1. **Install extra GNOME extensions** that apt doesn't ship — open Extension Manager and install:
   - ArcMenu
   - Blur my Shell
2. **Activate the WhiteSur theme** — open GNOME Tweaks → Appearance:
   - Applications: `WhiteSur-Dark` (or `WhiteSur-Light`)
   - Shell: same
   - Icons: `WhiteSur`
3. **Log out / back in** so the new GRUB resolution, keyboard layout, and GNOME extensions fully take effect.

### Microsoft Surface only

1. **Reboot** and verify the Surface kernel is active:
   ```sh
   uname -r   # should contain "surface"
   ```
2. **If Secure Boot is enabled**: on the blue MOK Manager screen after reboot, choose:
   `Enroll MOK` → `Continue` → `Yes` → password: **`SURFACE`**
3. **Power management**: avoid TLP on Surface — prefer `auto-cpufreq`:
   ```sh
   sudo apt install -y auto-cpufreq
   sudo auto-cpufreq --install
   ```

## Configure Claude Code MCP Servers

- Copy `.mcp` to your home directory:
  ```sh
  cp -r .mcp ~
  ```
- In `~/.mcp/strapi-mcp-server.config.json`, replace `<your-strapi-url>` and `<your-strapi-api-token>` with actual values.
- Copy the content of `.claude.mcp.json` and replace the `mcpServers` section in `~/.claude.json`.
- Verify:
  ```sh
  claude mcp list
  ```
  Expected output:
  ```
  filesystem: npx -y @modelcontextprotocol/server-filesystem /home/cpontet/repos - ✓ Connected
  convex:     npx -y convex@latest mcp start                                     - ✓ Connected
  strapi:     npx -y @bschauer/strapi-mcp-server@2.6.0                           - ✓ Connected
  memory:     npx -y @modelcontextprotocol/server-memory                         - ✓ Connected
  ```

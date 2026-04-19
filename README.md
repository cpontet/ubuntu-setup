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
- `tmux` (terminal multiplexer) with a managed `~/.tmux.conf`: prefix `Ctrl+a`, mouse support, truecolor, vim-style pane nav (`hjkl`) + resize (`HJKL`), `|` / `-` splits, copy mode yanks to the system clipboard (`xclip`), status line at top, session restore on reboot. TPM is installed and plugins (`sensible`, `resurrect`, `continuum`) are auto-bootstrapped.
- Modern CLI bundle: `ripgrep`, `fd`, `bat`, `eza`, `fzf` (with key-bindings + completion), `zoxide` (smarter `cd` via `z` / `zi`)
- CLI QoL: `btop`, `tldr`, `hyperfine`
- Enhanced bash completion (case-insensitive, colored, menu-complete via Tab)
- History tuning (10k lines, dedup)
- Aliases: `c=clear`, `p=pnpm`, `y=yarn`, `g=git`, `k=kubectl`, `pod=podman`, `docker=podman`, `lg=lazygit`, `bat=batcat`, `fd=fdfind`, `ll`, `la`, `l`, `repos=cd ~/repos`, `..`, `...`, `....`
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

**Go**
- Latest stable from go.dev, installed to `/usr/local/go` with `$HOME/go/bin` on PATH

**Rust**
- `rustup` + stable toolchain (`cargo`, `rustc`)

**.NET**
- .NET SDK 10

**Git tooling**
- `git-delta` (diff pager, wired into `~/.gitconfig` globally: side-by-side, line numbers, `zdiff3` merge style)
- `lazygit` (terminal UI for git, aliased as `lg`)
- `git-lfs`
- `pre-commit` (installed via `uv tool`)

**Cloud / DevOps CLIs**
- GitHub CLI (`gh`)
- GitLab CLI (`glab`)
- Azure CLI (`az`)
- AWS CLI (`aws`)
- Cloudflare Wrangler
- Clever Cloud CLI (`clever`)
- kubectl + k9s
- `kubectx`, `kubens`, `stern`
- Helm
- `direnv` (auto-load `.envrc` per project)

**Dev tooling**
- `mkcert` (local HTTPS CA)
- `just` (modern task runner)

**AI tooling**
- Claude Code (native binary)
- Ollama (local LLMs)

### Native Ubuntu Desktop only

Skipped under WSL.

**Browsers, editor & terminal**
- Brave browser
- Microsoft Edge — the script also writes a launcher per Edge profile (`cpontet`, `AP`, `OP`) into `~/.local/share/applications/`. `cpontet` and `AP` use the profile's own avatar; `OP` uses a European flag. If profiles don't exist yet, launch Edge once and sign in, then re-run the script.
- Mullvad Browser
- Visual Studio Code
- Alacritty (GPU-accelerated terminal) — **set as the system default terminal**; managed config at `~/.config/alacritty/alacritty.toml` uses `FiraCode Nerd Font Mono` 12 and auto-launches `tmux new-session -A -s main`, so every new window attaches to the same tmux session. `Ctrl+Alt+T` is rebound to Alacritty via a GNOME custom keybinding, and `update-alternatives` points `x-terminal-emulator` at Alacritty for any app that honors it.

**GNOME polish**
- WhiteSur GTK theme + matching icon theme (macOS-like look)
- Desktop wallpaper: play14 logo (white variant for light mode, black variant for dark mode), scaled on black letterbox fill so the 3.19:1 logo isn't cropped on 16:9 displays
- GNOME Terminal default font set to `FiraCode Nerd Font Mono 12`

**Apps**
- Flatpak + Flathub
- Media: VLC, GIMP, Evince (PDF), GNOME Sound Recorder, GParted, Shotcut (Flatpak)
- Communication: Discord (Flatpak), Slack (Flatpak), WhatsApp for Linux (Flatpak — `com.github.eneshecan.WhatsAppForLinux`)
- Cloud sync & meetings: Infomaniak kDrive, kChat, kMeet (official AppImages + `.desktop` entries), OneDriver (Microsoft OneDrive FUSE client — on-demand file access)
- AI: Claude Desktop (built locally from `aaddrick/claude-desktop-debian`)

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
   clever login
   ```

### Native Desktop only

1. **Activate the WhiteSur theme** — open GNOME Tweaks → Appearance:
   - Applications: `WhiteSur-Dark` (or `WhiteSur-Light`)
   - Shell: same
   - Icons: `WhiteSur`
2. **Log out / back in** so GRUB resolution, keyboard layout, and the Alacritty `Ctrl+Alt+T` custom keybinding all take effect.
3. **Read the Alacritty + tmux notes** (see below) — your terminal now auto-launches tmux; the section covers how to use it and how to opt out.
4. **Set up OneDriver** (see below) — it's installed but needs a one-time account link.

### Alacritty + tmux

Alacritty is the default terminal and is configured to auto-attach to a tmux session called `main` every time it launches. Both configs are written with a `# managed-by: ubuntu-setup` marker on the first line:

- `~/.config/alacritty/alacritty.toml`
- `~/.tmux.conf`

Re-running `setup.sh` **regenerates** any file that still starts with that marker (so you get config upgrades for free). **Delete the marker line** on either file to "adopt" it — the script will then leave it alone forever.

**Everyday usage**

- `Ctrl+Alt+T` → Alacritty → tmux session `main` (or a new session attached to `main`).
- Want a raw shell without tmux? `alacritty -e bash`.
- Inside tmux, the prefix is **`Ctrl+a`** (not the vanilla `Ctrl+b`). A double-tap sends a literal `Ctrl+a` to the underlying shell.

**tmux cheat sheet (with the managed config)**

| Keys | Action |
|---|---|
| `prefix` + `\|` / `-` | Split pane vertically / horizontally, preserving cwd |
| `prefix` + `h` / `j` / `k` / `l` | Navigate panes (vim-style) |
| `prefix` + `H` / `J` / `K` / `L` | Resize pane — repeatable while held |
| `prefix` + `r` | Reload `~/.tmux.conf` |
| `prefix` + `[` | Enter copy mode (vi keys); `v` to start select, `y` to yank to system clipboard |
| `prefix` + `I` / `U` | TPM: install / update plugins |

**Session restore**. `tmux-continuum` auto-saves every 15 minutes and restores on tmux startup, so your panes come back after a reboot. The first save happens after you've had an active session for 15 minutes.

**First-run clipboard note**. On native Wayland/X11 the `y` binding yanks to the system clipboard via `xclip` (installed automatically). Under WSL, `xclip` requires WSLg — if yanking doesn't work, swap the binding for `clip.exe`.

### OneDriver (Microsoft OneDrive)

OneDriver mounts OneDrive as a FUSE filesystem with on-demand download, similar to the "Files On-Demand" experience on Windows.

1. **Link an account.** Either launch **OneDriver** from the GNOME menu and pick an empty mount folder, or from a terminal:
   ```sh
   mkdir -p ~/OneDrive
   onedriver ~/OneDrive         # opens a browser window for Microsoft login, then mounts
   ```
   If the embedded login popup fails (blank window / WebKit issues on some GNOME setups), use the system browser instead:
   ```sh
   onedriver -a ~/OneDrive
   ```
2. **Auto-mount on login** via a systemd user service. Systemd escapes `/` in the path to `-`:
   ```sh
   systemctl --user enable --now onedriver@home-$USER-OneDrive.service
   systemctl --user status  onedriver@home-$USER-OneDrive.service
   ```
3. **Multiple accounts** (e.g. personal + work) — repeat step 1 with a different empty folder (e.g. `~/OneDrive-Work`) and enable a second service unit for that path.
4. **Unlink an account / reset state**:
   ```sh
   systemctl --user disable --now onedriver@home-$USER-OneDrive.service
   rm -rf ~/.cache/onedriver/<account-id>
   ```

**Known gotcha — Work/School accounts with Conditional Access.** If login ends with an error like `AADSTS53003`, your tenant blocks OneDriver's registered app ID. There is no client-side fix; you'd need either the official Microsoft client (Windows/macOS only) or `rclone` configured with your tenant's own app registration.

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

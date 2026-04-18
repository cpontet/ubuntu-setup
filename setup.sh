#!/bin/bash

# Ubuntu Automated Setup Script (WSL + Native Desktop)
# This script automates the installation and configuration of development tools
# and optionally a Zorin OS-like desktop experience on native Ubuntu.
# IDEMPOTENT: Safe to run multiple times without duplicating configurations

set -e  # Exit on any error

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

print_status() {
    echo -e "\n📦 $1..."
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_wsl() {
    grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null
}

is_surface() {
    local vendor product
    vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "")
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
    [[ "$vendor" == *"Microsoft"* ]] && [[ "$product" == *"Surface"* ]]
}

# Safely update .bashrc with idempotent sections using markers
update_bashrc_section() {
    local marker="$1"
    local content="$2"
    local start_marker="# ===== $marker - START ====="
    local end_marker="# ===== $marker - END ====="

    # Create backup only if this is the first time we're modifying .bashrc
    if [ ! -f ~/.bashrc.backup.original ]; then
        cp ~/.bashrc ~/.bashrc.backup.original
        echo "  Original .bashrc backed up to ~/.bashrc.backup.original"
    fi

    # Remove existing section if it exists
    if grep -q "$start_marker" ~/.bashrc; then
        sed -i "/$start_marker/,/$end_marker/d" ~/.bashrc
    fi

    # Add the new section
    echo -e "\n$start_marker" >> ~/.bashrc
    echo -e "$content" >> ~/.bashrc
    echo -e "$end_marker" >> ~/.bashrc
}

# Manage .bash_aliases file (add aliases idempotently)
manage_bash_aliases() {
    local aliases_file="$HOME/.bash_aliases"

    [ ! -f "$aliases_file" ] && touch "$aliases_file"

    add_alias_if_not_exists() {
        local alias_name="$1"
        local alias_command="$2"
        local alias_line="alias $alias_name='$alias_command'"

        if ! grep -q "^alias $alias_name=" "$aliases_file"; then
            echo "$alias_line" >> "$aliases_file"
            echo "  Added alias '$alias_name'"
        fi
    }

    add_alias_if_not_exists "c" "clear"
    add_alias_if_not_exists "p" "pnpm"
    add_alias_if_not_exists "y" "yarn"
    add_alias_if_not_exists "pod" "podman"
    add_alias_if_not_exists "docker" "podman"
    add_alias_if_not_exists "ll" "ls -alF"
    add_alias_if_not_exists "la" "ls -A"
    add_alias_if_not_exists "l" "ls -CF"
    add_alias_if_not_exists "repos" "cd ~/repos"
    add_alias_if_not_exists ".." "cd .."
    add_alias_if_not_exists "..." "cd ../.."
    add_alias_if_not_exists "...." "cd ../../.."

    # Ensure .bashrc sources .bash_aliases
    if ! grep -q "\.bash_aliases" ~/.bashrc; then
        BASH_ALIASES_SOURCE='
# Source .bash_aliases if it exists
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi'
        update_bashrc_section "BASH ALIASES SOURCING" "$BASH_ALIASES_SOURCE"
    fi
}

# ==============================================================================
# COMMON INSTALL FUNCTIONS (WSL + Native)
# ==============================================================================

install_system_packages() {
    print_status "Updating and upgrading system packages"
    sudo apt update && sudo apt upgrade -y

    print_status "Installing essential packages"
    sudo apt install -y \
        git \
        bash-completion \
        command-not-found \
        curl \
        wget \
        unzip \
        jq \
        tree \
        htop \
        neofetch \
        build-essential \
        python3-pip \
        python3-venv
}

install_podman() {
    print_status "Installing Podman and podman-compose"
    sudo apt install -y podman podman-compose
}

install_starship() {
    print_status "Installing Starship prompt"
    if ! command_exists starship; then
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    else
        echo "  Starship is already installed"
    fi

    STARSHIP_CONFIG='# Starship Prompt Configuration
eval "$(starship init bash)"'
    update_bashrc_section "STARSHIP PROMPT" "$STARSHIP_CONFIG"
}

install_nvm() {
    print_status "Installing NVM (Node Version Manager)"
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    else
        echo "  NVM is already installed"
    fi

    # Source nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    NVM_CONFIG='# NVM (Node Version Manager) Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
    update_bashrc_section "NVM CONFIGURATION" "$NVM_CONFIG"
}

install_node_lts() {
    print_status "Installing Node.js LTS via NVM"
    if command_exists nvm; then
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
        echo "  Node.js $(node --version), npm $(npm --version)"
    else
        echo "  NVM not found. Restart terminal and run: nvm install --lts"
        return
    fi

    # Enable Corepack and install pnpm + yarn
    print_status "Enabling Corepack and installing pnpm + yarn"
    if command_exists corepack; then
        corepack enable
        corepack prepare pnpm@latest --activate
        corepack prepare yarn@latest --activate
        echo "  pnpm $(pnpm --version 2>/dev/null || echo 'installed'), yarn $(yarn --version 2>/dev/null || echo 'installed')"
    else
        echo "  Corepack not available, installing pnpm and yarn via npm"
        npm install -g pnpm yarn
    fi
}

install_claude_code() {
    print_status "Installing Claude Code (native binary)"
    if command_exists claude; then
        echo "  Claude Code is already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
        return
    fi

    # Clean up old npm install if present
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true

    # Install via official native installer
    curl -fsSL https://claude.ai/install.sh | bash
}

install_gh() {
    print_status "Installing GitHub CLI"
    if ! command_exists gh; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
        && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update \
        && sudo apt install gh -y
    else
        echo "  GitHub CLI is already installed"
    fi
}

install_glab() {
    print_status "Installing GitLab CLI"
    if command_exists glab; then
        echo "  GitLab CLI is already installed"
        return
    fi

    local arch deb_url tmp_deb
    arch=$(dpkg --print-architecture)
    deb_url=$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest" \
        | jq -r --arg a "$arch" '.assets.links[] | select(.name | test("linux_"+$a+"\\.deb$")) | .url' \
        | head -1)
    if [ -z "$deb_url" ]; then
        echo "  Could not find glab .deb for architecture $arch, skipping"
        return
    fi
    tmp_deb=$(mktemp --suffix=.deb)
    curl -fsSL -o "$tmp_deb" "$deb_url"
    sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
    rm -f "$tmp_deb"
}

install_az() {
    print_status "Installing Azure CLI"
    if ! command_exists az; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        echo "  Azure CLI is already installed"
    fi
}

install_aws() {
    print_status "Installing AWS CLI"
    if ! command_exists aws; then
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
        && unzip -q awscliv2.zip \
        && sudo ./aws/install \
        && rm -rf awscliv2.zip aws/
    else
        echo "  AWS CLI is already installed"
    fi
}

install_wrangler() {
    print_status "Installing Cloudflare CLI (Wrangler)"
    if ! command_exists wrangler; then
        if command_exists npm; then
            npm install -g wrangler
        else
            echo "  npm not available. Wrangler installation skipped"
        fi
    else
        echo "  Wrangler is already installed"
    fi
}

setup_bash_completions() {
    print_status "Setting up bash completions"
    mkdir -p ~/.bash_completion.d

    # npm completion
    if command_exists npm; then
        npm completion > ~/.bash_completion.d/npm_completion 2>/dev/null || true
    fi

    # GitHub CLI completion
    if command_exists gh; then
        gh completion -s bash > ~/.bash_completion.d/gh_completion 2>/dev/null || true
    fi

    # GitLab CLI completion
    if command_exists glab; then
        glab completion -s bash > ~/.bash_completion.d/glab_completion 2>/dev/null || true
    fi

    # Azure CLI completion
    if command_exists az; then
        az completion > ~/.bash_completion.d/az_completion 2>/dev/null || true
    fi

    # AWS CLI completion
    if command_exists aws; then
        aws_completer_path=$(which aws_completer 2>/dev/null)
        if [ -n "$aws_completer_path" ]; then
            echo "complete -C '$aws_completer_path' aws" > ~/.bash_completion.d/aws_completion
        fi
    fi

    # Podman completion
    if command_exists podman; then
        podman completion bash > ~/.bash_completion.d/podman_completion 2>/dev/null || true
    fi

    # Git alias completion
    if command_exists git; then
        cat > ~/.bash_completion.d/git_enhancements << 'EOF'
# Enhanced git completions
alias g='git'
if [[ $(type -t _git) == function ]]; then
    complete -o default -o nospace -F _git g
fi
EOF
    fi
}

setup_bashrc() {
    print_status "Configuring enhanced bash settings"

    # Migrate old marker name if present
    if grep -q "AUTOMATED WSL SETUP - START" ~/.bashrc 2>/dev/null; then
        sed -i '/===== AUTOMATED WSL SETUP - START =====/,/===== AUTOMATED WSL SETUP - END =====/d' ~/.bashrc
    fi

    BASH_CONFIG='
# Enhanced Bash Completion Configuration

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Load custom completions
if [ -d ~/.bash_completion.d ]; then
    for completion in ~/.bash_completion.d/*; do
        [ -r "$completion" ] && . "$completion"
    done
fi

# Completion behavior
bind "set completion-ignore-case on"
bind "set show-all-if-ambiguous on"
bind "set menu-complete-display-prefix on"
bind '\''"\t": menu-complete'\''
bind '\''"\e[Z": menu-complete-backward'\''
bind "set visible-stats on"
bind "set colored-stats on"

# Shell options
shopt -s hostcomplete extglob dirspell autocd globstar histappend

# History settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups

# Create ~/repos directory if it doesn'\''t exist
[ -d "$HOME/repos" ] || mkdir -p "$HOME/repos"
'
    update_bashrc_section "AUTOMATED SETUP" "$BASH_CONFIG"

    # Create ~/repos now
    mkdir -p ~/repos
}

# ==============================================================================
# ADDITIONAL TOOLS
# ==============================================================================

install_direnv() {
    print_status "Installing direnv"
    if ! command_exists direnv; then
        sudo apt install -y direnv
    else
        echo "  direnv is already installed"
    fi

    DIRENV_CONFIG='# direnv hook
eval "$(direnv hook bash)"'
    update_bashrc_section "DIRENV" "$DIRENV_CONFIG"
}

install_kubectl() {
    print_status "Installing kubectl"
    if ! command_exists kubectl; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key \
            | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
            | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
        sudo apt update && sudo apt install -y kubectl
    else
        echo "  kubectl is already installed"
    fi

    # kubectl completion
    if command_exists kubectl; then
        kubectl completion bash > ~/.bash_completion.d/kubectl_completion 2>/dev/null || true
        # alias k=kubectl with completion
        echo 'alias k=kubectl
complete -o default -F __start_kubectl k' > ~/.bash_completion.d/kubectl_alias 2>/dev/null || true
    fi
}

install_k9s() {
    print_status "Installing k9s"
    if ! command_exists k9s; then
        local k9s_version
        k9s_version=$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')
        local arch
        arch=$(dpkg --print-architecture)
        if [ "$arch" = "amd64" ]; then arch="amd64"; else arch="arm64"; fi
        curl -fsSL "https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_${arch}.tar.gz" \
            | sudo tar xz -C /usr/local/bin k9s
    else
        echo "  k9s is already installed"
    fi
}

install_helm() {
    print_status "Installing Helm"
    if ! command_exists helm; then
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    else
        echo "  Helm is already installed"
    fi

    if command_exists helm; then
        helm completion bash > ~/.bash_completion.d/helm_completion 2>/dev/null || true
    fi
}

install_ollama() {
    print_status "Installing Ollama"
    if ! command_exists ollama; then
        curl -fsSL https://ollama.com/install.sh | sh
    else
        echo "  Ollama is already installed"
    fi
}

install_uv() {
    print_status "Installing uv (Python package manager)"
    if ! command_exists uv; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    else
        echo "  uv is already installed"
    fi
}

install_bun() {
    print_status "Installing Bun (JavaScript runtime & package manager)"
    if ! command_exists bun; then
        curl -fsSL https://bun.sh/install | bash
    else
        echo "  Bun is already installed ($(bun --version 2>/dev/null || echo 'version unknown'))"
    fi

    BUN_CONFIG='# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"'
    update_bashrc_section "BUN" "$BUN_CONFIG"

    # Make bun available in the current shell
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
}

install_sdkman() {
    print_status "Installing SDKMAN (JVM version manager)"
    if [ -d "$HOME/.sdkman" ]; then
        echo "  SDKMAN is already installed"
    else
        curl -s "https://get.sdkman.io?rcupdate=false" | bash
    fi

    SDKMAN_CONFIG='# SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && source "$SDKMAN_DIR/bin/sdkman-init.sh"'
    update_bashrc_section "SDKMAN" "$SDKMAN_CONFIG"

    # Make sdk available in the current shell
    export SDKMAN_DIR="$HOME/.sdkman"
    # shellcheck source=/dev/null
    [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
}

install_jdk() {
    local required_major=25
    local sdkman_jdk_id="25-tem"
    print_status "Installing OpenJDK ${required_major} (Temurin via SDKMAN)"

    if command_exists java; then
        local java_ver
        java_ver=$(java -version 2>&1 | head -1 | grep -oP '\d+' | head -1 || echo "0")
        if [ "$java_ver" -ge "$required_major" ]; then
            echo "  JDK $java_ver is already installed"
            return
        fi
    fi

    if [ ! -d "$HOME/.sdkman" ]; then
        echo "  SDKMAN not found, skipping JDK install"
        return
    fi

    export SDKMAN_DIR="$HOME/.sdkman"
    # shellcheck source=/dev/null
    [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

    if command_exists sdk; then
        sdk install java "$sdkman_jdk_id" || true
    else
        echo "  sdk command not available, restart terminal and run: sdk install java $sdkman_jdk_id"
    fi
}

install_typescript_lsp() {
    print_status "Installing typescript-language-server (TypeScript LSP for Claude Code)"
    if command_exists typescript-language-server; then
        echo "  typescript-language-server is already installed"
        return
    fi

    if command_exists bun; then
        bun install -g typescript-language-server typescript
    elif command_exists npm; then
        npm install -g typescript-language-server typescript
    else
        echo "  Neither bun nor npm available, skipping"
    fi
}

install_jdtls() {
    local jdtls_version="1.57.0"
    local jdtls_build="202602261110"
    local jdtls_dir="$HOME/jdtls"
    print_status "Installing jdtls ${jdtls_version} (Java LSP for Claude Code)"

    if command_exists jdtls; then
        echo "  jdtls is already installed"
        return
    fi

    local tarball="jdt-language-server-${jdtls_version}-${jdtls_build}.tar.gz"
    local url="https://download.eclipse.org/jdtls/milestones/${jdtls_version}/${tarball}"

    curl -fSL -o "/tmp/${tarball}" "${url}"
    rm -rf "$jdtls_dir"
    mkdir -p "$jdtls_dir"
    tar xzf "/tmp/${tarball}" -C "$jdtls_dir"
    rm -f "/tmp/${tarball}"

    sudo ln -sf "$jdtls_dir/bin/jdtls" /usr/local/bin/jdtls
}

install_nerd_fonts() {
    print_status "Installing Nerd Fonts (developer fonts with icons)"
    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"

    local nf_version
    nf_version=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
        | grep -oP '"tag_name":\s*"\K[^"]+')
    if [ -z "$nf_version" ]; then
        echo "  Could not determine latest Nerd Fonts version, skipping"
        return
    fi

    local fonts=(FiraCode JetBrainsMono Meslo Hack)
    local installed=0
    for font in "${fonts[@]}"; do
        if [ -d "$fonts_dir/${font}NerdFont" ]; then
            echo "  $font Nerd Font already installed"
            continue
        fi
        echo "  Installing $font Nerd Font ($nf_version)..."
        local tmpfile=/tmp/${font}.zip
        curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${nf_version}/${font}.zip" -o "$tmpfile"
        mkdir -p "$fonts_dir/${font}NerdFont"
        unzip -oq "$tmpfile" -d "$fonts_dir/${font}NerdFont"
        rm -f "$tmpfile"
        installed=1
    done

    if [ "$installed" = "1" ] && command_exists fc-cache; then
        fc-cache -f "$fonts_dir" > /dev/null 2>&1 || true
    fi
}

# ==============================================================================
# NATIVE UBUNTU DESKTOP FUNCTIONS (not WSL)
# ==============================================================================

install_brave() {
    print_status "Installing Brave browser"
    if ! command_exists brave-browser; then
        curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
            | sudo tee /usr/share/keyrings/brave-browser-archive-keyring.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
            | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
        sudo apt update && sudo apt install -y brave-browser
    else
        echo "  Brave is already installed"
    fi
}

install_edge() {
    print_status "Installing Microsoft Edge"
    if ! command_exists microsoft-edge; then
        if [ ! -f /usr/share/keyrings/microsoft.gpg ]; then
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
                | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null
        fi
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/edge stable main" \
            | sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null
        sudo apt update && sudo apt install -y microsoft-edge-stable
    else
        echo "  Microsoft Edge is already installed"
    fi
}

install_vscode() {
    print_status "Installing Visual Studio Code"
    if ! command_exists code; then
        if [ ! -f /usr/share/keyrings/microsoft.gpg ]; then
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
                | gpg --dearmor | sudo tee /usr/share/keyrings/microsoft.gpg > /dev/null
        fi
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
            | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        sudo apt update && sudo apt install -y code
    else
        echo "  VS Code is already installed"
    fi
}

install_gnome_extensions() {
    print_status "Installing GNOME extensions and tweaks"
    sudo apt install -y \
        gnome-tweaks \
        gnome-shell-extension-manager \
        gnome-shell-extensions

    # Install extensions available via apt
    sudo apt install -y \
        gnome-shell-extension-dash-to-panel \
        gnome-shell-extension-gsconnect \
        2>/dev/null || true

    # ArcMenu, Blur my Shell, and User Themes may not be in apt —
    # install via gnome-extensions CLI if available
    print_status "Enabling GNOME extensions"

    # Enable installed extensions (they may need a GNOME Shell restart to take effect)
    for ext in dash-to-panel@jderose9.github.com user-theme@gnome-shell-extensions.gcampax.github.com gsconnect@andyholmes.github.io; do
        gnome-extensions enable "$ext" 2>/dev/null || true
    done

    echo ""
    echo "  NOTE: For ArcMenu and Blur my Shell, open Extension Manager and install:"
    echo "    - ArcMenu"
    echo "    - Blur my Shell"
    echo "  These cannot be installed non-interactively."
}

install_flatpak() {
    print_status "Installing Flatpak and Flathub"
    sudo apt install -y flatpak gnome-software-plugin-flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_desktop_apps() {
    print_status "Installing desktop productivity apps"

    # Apps from apt
    sudo apt install -y \
        vlc \
        gimp \
        evince \
        gnome-sound-recorder \
        gparted

    # Shotcut (video editor) — better installed via Flatpak
    print_status "Installing Shotcut (video editor) via Flatpak"
    flatpak install -y flathub org.shotcut.Shotcut 2>/dev/null || true
}

install_gtk_theme() {
    print_status "Installing WhiteSur GTK theme (macOS-like appearance)"
    local theme_dir="$HOME/.local/share/themes"
    local repo_dir="/tmp/WhiteSur-gtk-theme"

    if [ -d "$theme_dir/WhiteSur-Dark" ] || [ -d "$theme_dir/WhiteSur-Light" ]; then
        echo "  WhiteSur theme is already installed"
        return
    fi

    sudo apt install -y sassc libglib2.0-dev-bin 2>/dev/null || true

    if [ -d "$repo_dir" ]; then
        sudo rm -rf "$repo_dir"
    fi

    git clone --depth 1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$repo_dir"
    cd "$repo_dir"
    ./install.sh
    cd -

    # Also install the icon theme
    local icon_repo="/tmp/WhiteSur-icon-theme"
    if [ ! -d "$HOME/.local/share/icons/WhiteSur" ]; then
        if [ -d "$icon_repo" ]; then sudo rm -rf "$icon_repo"; fi
        git clone --depth 1 https://github.com/vinceliuice/WhiteSur-icon-theme.git "$icon_repo"
        cd "$icon_repo"
        ./install.sh
        cd -
    fi

    echo ""
    echo "  Theme installed. To activate:"
    echo "    1. Open GNOME Tweaks"
    echo "    2. Go to Appearance"
    echo "    3. Select WhiteSur-Dark or WhiteSur-Light for Applications and Shell"
    echo "    4. Select WhiteSur icons"
}

setup_gnome_terminal_font() {
    print_status "Setting GNOME Terminal default font to FiraCode Nerd Font"
    if ! command_exists gnome-terminal || ! command_exists gsettings; then
        echo "  GNOME Terminal or gsettings not found, skipping"
        return
    fi
    local default_profile
    default_profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
    if [ -z "$default_profile" ]; then
        echo "  Could not determine default GNOME Terminal profile, skipping"
        return
    fi
    local profile_path="/org/gnome/terminal/legacy/profiles:/:$default_profile/"
    gsettings set "org.gnome.Terminal.Legacy.Profile:$profile_path" use-system-font false
    gsettings set "org.gnome.Terminal.Legacy.Profile:$profile_path" font 'FiraCode Nerd Font Mono 12'
}

setup_keyboard_belgian() {
    print_status "Setting keyboard layout to Belgian (be)"
    if grep -q '^XKBLAYOUT="be"' /etc/default/keyboard 2>/dev/null; then
        echo "  Keyboard is already set to Belgian"
        return
    fi
    sudo sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="be"/' /etc/default/keyboard
    sudo dpkg-reconfigure -f noninteractive keyboard-configuration
    sudo setupcon --force || true
    # Propagate to initramfs so the LUKS unlock prompt also uses Belgian layout
    sudo update-initramfs -u
}

setup_grub_resolution() {
    print_status "Configuring GRUB resolution for HiDPI displays"
    local grub_file=/etc/default/grub
    local changed=0

    if grep -qE '^GRUB_GFXMODE=1920x1080$' "$grub_file"; then
        echo "  GRUB_GFXMODE already set to 1920x1080"
    elif grep -qE '^#?GRUB_GFXMODE=' "$grub_file"; then
        sudo sed -i 's/^#\?GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080/' "$grub_file"
        changed=1
    else
        echo 'GRUB_GFXMODE=1920x1080' | sudo tee -a "$grub_file" > /dev/null
        changed=1
    fi

    if ! grep -qE '^GRUB_GFXPAYLOAD_LINUX=' "$grub_file"; then
        echo 'GRUB_GFXPAYLOAD_LINUX=keep' | sudo tee -a "$grub_file" > /dev/null
        changed=1
    fi

    if [ "$changed" = "1" ]; then
        sudo update-grub
    fi
}

install_grub_theme() {
    print_status "Installing GRUB theme (vimix, 1080p)"
    if [ -d /boot/grub/themes/vimix ]; then
        echo "  GRUB vimix theme is already installed"
        return
    fi
    local repo=/tmp/grub2-themes
    [ -d "$repo" ] && rm -rf "$repo"
    git clone --depth=1 https://github.com/vinceliuice/grub2-themes.git "$repo"
    sudo "$repo/install.sh" -t vimix -s 1080p
}

# ==============================================================================
# MICROSOFT SURFACE (kernel + drivers)
# ==============================================================================

install_surface_kernel() {
    print_status "Installing Linux Surface kernel and drivers"

    if dpkg -l linux-image-surface 2>/dev/null | grep -q '^ii'; then
        echo "  Linux Surface kernel already installed"
        return
    fi

    # Prerequisites + Intel microcode (needed to avoid boot issues on Intel Surfaces)
    sudo apt install -y wget gnupg2 curl intel-microcode

    # Add Linux Surface signing key (idempotent)
    if [ ! -f /etc/apt/trusted.gpg.d/linux-surface.gpg ]; then
        wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
            | gpg --dearmor | sudo dd of=/etc/apt/trusted.gpg.d/linux-surface.gpg
    fi

    # Add Linux Surface apt repository (idempotent)
    if [ ! -f /etc/apt/sources.list.d/linux-surface.list ]; then
        echo "deb [arch=amd64] https://pkg.surfacelinux.com/debian release main" \
            | sudo tee /etc/apt/sources.list.d/linux-surface.list > /dev/null
        sudo apt update
    fi

    # Kernel, headers, and Surface-specific packages
    # libwacom-surface: pen/stylus support
    # iptsd: Intel Precise Touch & Stylus Daemon (touchscreen/pen)
    sudo apt install -y \
        linux-image-surface \
        linux-headers-surface \
        libwacom-surface \
        iptsd

    # Secure Boot MOK (optional — allows booting with Secure Boot enabled)
    sudo apt install -y linux-surface-secureboot-mok 2>/dev/null \
        || echo "  Secure Boot MOK installation skipped (optional)"

    sudo update-grub

    echo ""
    echo "  Surface kernel installed. Next steps:"
    echo "    1. Reboot — verify with: uname -r  (should contain 'surface')"
    echo "    2. If Secure Boot is enabled: on the blue MOK Manager screen after reboot,"
    echo "       choose 'Enroll MOK' -> 'Continue' -> 'Yes' and enter password: SURFACE"
    echo "    3. Power tip: avoid TLP on Surface; prefer auto-cpufreq:"
    echo "         sudo apt install -y auto-cpufreq && sudo auto-cpufreq --install"
}

# ==============================================================================
# MAIN FLOW
# ==============================================================================

echo "🚀 Starting Ubuntu setup..."
if is_wsl; then
    echo "   Environment: WSL (Windows Subsystem for Linux)"
else
    echo "   Environment: Native Ubuntu Desktop"
fi
echo "=================================================="

# --- Common (both WSL and native) ---
install_system_packages
install_podman
install_starship
install_nvm
install_node_lts
install_claude_code
install_gh
install_glab
install_az
install_aws
install_wrangler
install_direnv
install_kubectl
install_k9s
install_helm
install_ollama
install_uv
install_bun
install_sdkman
install_jdk
install_typescript_lsp
install_jdtls
install_nerd_fonts
setup_bash_completions
manage_bash_aliases
setup_bashrc

# --- Native Ubuntu Desktop only ---
if ! is_wsl; then
    echo ""
    echo "=================================================="
    echo "🖥️  Installing desktop applications..."
    echo "=================================================="

    install_brave
    install_edge
    install_vscode
    install_gnome_extensions
    install_flatpak
    install_desktop_apps
    install_gtk_theme
    setup_gnome_terminal_font
    setup_keyboard_belgian
    setup_grub_resolution
    install_grub_theme

    if is_surface; then
        echo ""
        echo "=================================================="
        echo "💻 Microsoft Surface detected ($(cat /sys/class/dmi/id/product_name 2>/dev/null))"
        echo "=================================================="
        install_surface_kernel
    fi
fi

# ==============================================================================
# SUMMARY
# ==============================================================================

echo ""
echo "=================================================="
echo "🎉 Setup completed successfully!"
echo "=================================================="
echo ""
echo "📋 Installed components:"
echo "   ✓ System packages (git, curl, jq, tree, htop, neofetch, build-essential, python3)"
echo "   ✓ Podman + podman-compose (with docker alias)"
echo "   ✓ Starship prompt"
echo "   ✓ NVM + Node.js LTS + Corepack + pnpm + yarn"
echo "   ✓ Claude Code (native binary)"
echo "   ✓ GitHub CLI (gh)"
echo "   ✓ GitLab CLI (glab)"
echo "   ✓ Azure CLI"
echo "   ✓ AWS CLI"
echo "   ✓ Cloudflare CLI (Wrangler)"
echo "   ✓ direnv (auto-load .envrc per project)"
echo "   ✓ kubectl + k9s (Kubernetes CLI + terminal UI)"
echo "   ✓ Helm (Kubernetes package manager)"
echo "   ✓ Ollama (local LLMs)"
echo "   ✓ uv (fast Python package manager)"
echo "   ✓ Bun (JavaScript runtime & package manager)"
echo "   ✓ SDKMAN + OpenJDK 25 (Temurin)"
echo "   ✓ typescript-language-server (TypeScript LSP)"
echo "   ✓ jdtls (Eclipse Java LSP)"
echo "   ✓ Nerd Fonts (FiraCode, JetBrainsMono, Meslo, Hack — with icons)"
echo "   ✓ Enhanced bash completion for all tools"
echo "   ✓ Bash aliases (p=pnpm, y=yarn, c=clear, g=git, k=kubectl, pod/docker=podman)"
echo "   ✓ ~/repos workspace directory"

if ! is_wsl; then
    echo ""
    echo "🖥️  Desktop components:"
    echo "   ✓ Brave browser"
    echo "   ✓ Microsoft Edge"
    echo "   ✓ Visual Studio Code"
    echo "   ✓ GNOME Tweaks + Extension Manager"
    echo "   ✓ Dash to Panel + GSConnect extensions"
    echo "   ✓ Flatpak + Flathub"
    echo "   ✓ VLC, GIMP, Evince (PDF), Shotcut (video), Sound Recorder"
    echo "   ✓ WhiteSur GTK + icon theme"
    echo "   ✓ GNOME Terminal default font: FiraCode Nerd Font Mono 12"
    echo "   ✓ Belgian keyboard layout (console + X11 + LUKS prompt)"
    echo "   ✓ GRUB 1080p resolution (readable on HiDPI)"
    echo "   ✓ GRUB vimix theme"
    echo ""
    echo "   Manual steps needed:"
    echo "     - Open Extension Manager and install: ArcMenu, Blur my Shell"
    echo "     - Open GNOME Tweaks to activate WhiteSur theme and icons"

    if is_surface; then
        echo ""
        echo "💻 Microsoft Surface:"
        echo "   ✓ linux-image-surface + linux-headers-surface"
        echo "   ✓ intel-microcode"
        echo "   ✓ libwacom-surface + iptsd (pen/touch)"
        echo "   ✓ Secure Boot MOK (if supported)"
        echo "   → Reboot required; see Surface notes above."
    fi
fi

echo ""
echo "🔄 Next steps:"
echo "   1. Restart your terminal or run: source ~/.bashrc"
echo "   2. Verify: claude --version, gh --version, glab --version"
echo ""
echo "📋 Script completed at: $(date)"

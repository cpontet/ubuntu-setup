#!/bin/bash

# Ubuntu Automated Setup Script (WSL + Native Desktop)
# This script automates the installation and configuration of development tools
# and optionally a Zorin OS-like desktop experience on native Ubuntu.
# IDEMPOTENT: Safe to run multiple times without duplicating configurations

set -o pipefail  # pipe fails if any command in it fails

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

FAILED_STEPS=()

# Run a step and record failure without aborting the whole script.
# The step name is the first argument (typically the function name).
run_step() {
    local step="$1"
    shift
    "$step" "$@"
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        FAILED_STEPS+=("$step (exit $exit_code)")
        echo "  ⚠️  Step '$step' failed with exit $exit_code — continuing"
    fi
    return 0
}

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
    # Ubuntu ships bat/fd as batcat/fdfind; alias to the conventional names
    add_alias_if_not_exists "bat" "batcat"
    add_alias_if_not_exists "fd" "fdfind"
    add_alias_if_not_exists "lg" "lazygit"

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

install_clever_tools() {
    print_status "Installing Clever Cloud CLI (clever-tools)"
    if command_exists clever; then
        echo "  Clever Cloud CLI is already installed ($(clever version 2>/dev/null | head -1 || echo 'version unknown'))"
        return
    fi

    if [ ! -f /usr/share/keyrings/cc-nexus-deb.gpg ]; then
        curl -fsSL https://clever-tools.clever-cloud.com/gpg/cc-nexus-deb.public.gpg.key \
            | sudo gpg --dearmor -o /usr/share/keyrings/cc-nexus-deb.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/clever-tools.list ]; then
        echo "deb [signed-by=/usr/share/keyrings/cc-nexus-deb.gpg] https://nexus.clever-cloud.com/repository/deb/ stable main" \
            | sudo tee /etc/apt/sources.list.d/clever-tools.list > /dev/null
        sudo apt update
    fi
    sudo apt install -y clever-tools
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

    # Clever Cloud CLI completion
    if command_exists clever; then
        clever --bash-autocomplete-script "$(command -v clever)" > ~/.bash_completion.d/clever_completion 2>/dev/null || true
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

install_modern_cli() {
    print_status "Installing modern CLI bundle (ripgrep, fd, bat, eza, fzf, zoxide)"
    sudo apt install -y ripgrep fd-find bat eza fzf zoxide

    MODERN_CLI_CONFIG='# fzf shell integration (key bindings + completion)
if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    . /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [ -f /usr/share/bash-completion/completions/fzf ]; then
    . /usr/share/bash-completion/completions/fzf
fi
# zoxide (smarter cd): use `z <dir>` or `zi` for interactive
command -v zoxide >/dev/null && eval "$(zoxide init bash)"'
    update_bashrc_section "MODERN CLI" "$MODERN_CLI_CONFIG"
}

install_tmux() {
    print_status "Installing tmux"
    if ! command_exists tmux; then
        sudo apt install -y tmux
    else
        echo "  tmux is already installed ($(tmux -V))"
    fi
}

setup_tmux_config() {
    print_status "Configuring tmux (managed ~/.tmux.conf + TPM + plugins)"
    local marker="# managed-by: ubuntu-setup"
    local tmux_conf="$HOME/.tmux.conf"

    # xclip is needed for the copy-mode → system clipboard bridge
    if ! command_exists xclip; then
        sudo apt install -y xclip
    fi

    if [ -f "$tmux_conf" ] && ! head -1 "$tmux_conf" | grep -q "^$marker"; then
        echo "  Existing user-customized $tmux_conf — not overwriting"
    else
        cat > "$tmux_conf" << 'EOF'
# managed-by: ubuntu-setup
# Remove the marker line above to take ownership of this file.

# Prefix: Ctrl+a (more ergonomic than Ctrl+b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# General
set  -g default-terminal "tmux-256color"
set -ga terminal-overrides ",alacritty:Tc,*256col*:Tc"
set  -g mouse on
set  -g history-limit 100000
set  -g base-index 1
setw -g pane-base-index 1
set  -g renumber-windows on
set  -s escape-time 0
set  -g focus-events on

# Reload config
bind r source-file ~/.tmux.conf \; display "tmux.conf reloaded"

# Intuitive splits that preserve cwd
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Vim-style pane navigation + resize
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Copy mode (vi) → system clipboard
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"

# Status line
set -g status-position top
set -g status-interval 5
set -g status-style "bg=default,fg=default"
set -g status-left  "#[fg=green,bold] #S "
set -g status-right "#[fg=cyan] %Y-%m-%d #[fg=yellow] %H:%M "
set -g window-status-current-style "fg=black,bg=cyan,bold"

# TPM plugins (install with prefix + I, update with prefix + U)
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore   'on'
set -g @continuum-save-interval '15'

# Init TPM — keep at the very bottom
run '~/.tmux/plugins/tpm/tpm'
EOF
        echo "  Wrote managed $tmux_conf"
    fi

    # Install TPM (tmux plugin manager)
    local tpm_dir="$HOME/.tmux/plugins/tpm"
    if [ ! -d "$tpm_dir" ]; then
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$tpm_dir"
    fi

    # Bootstrap plugins non-interactively
    if [ -x "$tpm_dir/bin/install_plugins" ]; then
        "$tpm_dir/bin/install_plugins" >/dev/null 2>&1 || true
    fi
}

install_git_polish() {
    print_status "Installing git-delta and lazygit"

    # git-delta (apt)
    if ! command_exists delta; then
        sudo apt install -y git-delta
    else
        echo "  git-delta is already installed"
    fi

    # lazygit (GitHub releases — not in apt)
    if ! command_exists lazygit; then
        local lg_version arch tarball
        lg_version=$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
            | grep -oP '"tag_name":\s*"v\K[^"]+')
        if [ -z "$lg_version" ]; then
            echo "  Could not determine latest lazygit version, skipping"
        else
            arch=$(dpkg --print-architecture)
            case "$arch" in
                amd64) arch=x86_64 ;;
                arm64) arch=arm64 ;;
                *) echo "  Unsupported arch for lazygit: $arch"; arch="" ;;
            esac
            if [ -n "$arch" ]; then
                tarball="/tmp/lazygit_${lg_version}_Linux_${arch}.tar.gz"
                curl -fsSL -o "$tarball" \
                    "https://github.com/jesseduffield/lazygit/releases/download/v${lg_version}/lazygit_${lg_version}_Linux_${arch}.tar.gz"
                sudo tar -xzf "$tarball" -C /usr/local/bin lazygit
                rm -f "$tarball"
            fi
        fi
    else
        echo "  lazygit is already installed ($(lazygit --version 2>/dev/null | head -1))"
    fi

    # Wire delta into git (only if delta is actually installed)
    if command_exists delta; then
        git config --global core.pager delta
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.line-numbers true
        git config --global delta.side-by-side true
        git config --global merge.conflictstyle zdiff3
    fi
}

install_rust() {
    print_status "Installing Rust toolchain (rustup)"
    if command_exists rustc && command_exists cargo; then
        echo "  Rust is already installed ($(rustc --version))"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --default-toolchain stable --no-modify-path
    fi

    RUST_CONFIG='# Rust (cargo) environment
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'
    update_bashrc_section "RUST" "$RUST_CONFIG"

    # Make cargo available in the current shell
    # shellcheck source=/dev/null
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
}

install_dotnet() {
    print_status "Installing .NET SDK 10"
    if command_exists dotnet && dotnet --list-sdks 2>/dev/null | grep -q "^10\."; then
        echo "  .NET SDK 10 is already installed"
        return
    fi
    sudo apt install -y dotnet-sdk-10.0
}

install_go() {
    print_status "Installing Go toolchain (latest from go.dev)"
    local latest arch tarball install_dir="/usr/local/go"
    latest=$(curl -fsSL --max-time 30 "https://go.dev/dl/?mode=json" | jq -r '.[0].version')
    if [ -z "$latest" ] || [ "$latest" = "null" ]; then
        echo "  Could not determine latest Go version, skipping"
        return
    fi
    if command_exists go && [ "$(go version | awk '{print $3}')" = "$latest" ]; then
        echo "  Go $latest is already installed"
    else
        arch=$(dpkg --print-architecture)
        tarball="/tmp/${latest}.linux-${arch}.tar.gz"
        echo "  Downloading ${latest}.linux-${arch}.tar.gz (~150MB)..."
        # -# shows a progress bar; --max-time guards against a hung connection
        curl -fL --max-time 600 -# -o "$tarball" "https://go.dev/dl/${latest}.linux-${arch}.tar.gz"
        sudo rm -rf "$install_dir"
        sudo tar -C /usr/local -xzf "$tarball"
        rm -f "$tarball"
    fi

    GO_CONFIG='# Go toolchain
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"'
    update_bashrc_section "GO" "$GO_CONFIG"
    export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
}

install_git_extras() {
    print_status "Installing git-lfs and pre-commit"

    if ! command_exists git-lfs; then
        sudo apt install -y git-lfs
        git lfs install
    else
        echo "  git-lfs is already installed"
    fi

    if command_exists pre-commit; then
        echo "  pre-commit is already installed"
    elif command_exists uv; then
        uv tool install pre-commit
    else
        echo "  uv not found, cannot install pre-commit"
    fi
}

install_k8s_extras() {
    print_status "Installing kubectx, kubens, and stern"

    # kubectx package includes kubens as a symlink
    sudo apt install -y kubectx

    if command_exists stern; then
        echo "  stern is already installed"
        return
    fi

    local version arch tarball
    version=$(curl -fsSL "https://api.github.com/repos/stern/stern/releases/latest" \
        | jq -r '.tag_name' | sed 's/^v//')
    if [ -z "$version" ]; then
        echo "  Could not determine latest stern version, skipping"
        return
    fi
    arch=$(dpkg --print-architecture)
    tarball="/tmp/stern.tar.gz"
    curl -fsSL -o "$tarball" \
        "https://github.com/stern/stern/releases/download/v${version}/stern_${version}_linux_${arch}.tar.gz"
    sudo tar -xzf "$tarball" -C /usr/local/bin stern
    rm -f "$tarball"
}

install_mkcert() {
    print_status "Installing mkcert (local HTTPS CA)"
    if command_exists mkcert; then
        echo "  mkcert is already installed"
        return
    fi
    sudo apt install -y mkcert
}

install_just() {
    print_status "Installing just (modern task runner)"
    if command_exists just; then
        echo "  just is already installed"
        return
    fi
    sudo apt install -y just
}

install_cli_qol() {
    print_status "Installing btop, tldr, hyperfine"
    sudo apt install -y btop tldr hyperfine
    # Seed tldr cache (quiet — failure here is non-fatal)
    command_exists tldr && tldr --update >/dev/null 2>&1 || true
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

install_mullvad_browser() {
    print_status "Installing Mullvad Browser"
    if command_exists mullvad-browser; then
        echo "  Mullvad Browser is already installed"
        return
    fi
    if [ ! -f /usr/share/keyrings/mullvad-keyring.asc ]; then
        sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc \
            https://repository.mullvad.net/deb/mullvad-keyring.asc
    fi
    echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$(dpkg --print-architecture)] https://repository.mullvad.net/deb/stable stable main" \
        | sudo tee /etc/apt/sources.list.d/mullvad.list > /dev/null
    sudo apt update
    sudo apt install -y mullvad-browser
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

install_alacritty() {
    print_status "Installing Alacritty terminal emulator"
    if ! command_exists alacritty; then
        sudo apt install -y alacritty
    else
        echo "  Alacritty is already installed ($(alacritty --version 2>/dev/null))"
    fi

    local marker="# managed-by: ubuntu-setup"
    local cfg_dir="$HOME/.config/alacritty"
    local cfg_file="$cfg_dir/alacritty.toml"

    if [ -f "$cfg_file" ] && ! head -1 "$cfg_file" | grep -q "^$marker"; then
        echo "  Existing user-customized $cfg_file — not overwriting"
        return
    fi

    mkdir -p "$cfg_dir"
    cat > "$cfg_file" << EOF
$marker
# Remove the marker line above to take ownership of this file.

[window]
padding = { x = 8, y = 8 }
opacity = 0.98

[font]
size = 12.0

[font.normal]
family = "FiraCode Nerd Font Mono"
style  = "Regular"

[font.bold]
family = "FiraCode Nerd Font Mono"
style  = "Bold"

[font.italic]
family = "FiraCode Nerd Font Mono"
style  = "Italic"

[scrolling]
history = 10000

[selection]
save_to_clipboard = true

# Auto-launch tmux: attach to session "main" or create it.
# To open a raw shell instead, run: alacritty -e bash
[terminal.shell]
program = "/bin/bash"
args = ["-l", "-c", "tmux new-session -A -s main"]
EOF
    echo "  Wrote managed Alacritty config to $cfg_file"
}

set_alacritty_default() {
    print_status "Setting Alacritty as the default terminal"
    if ! command_exists alacritty; then
        echo "  Alacritty not installed, skipping"
        return
    fi

    # System-level: apps that call x-terminal-emulator (xdg-terminal, Thunderbird, etc.)
    sudo update-alternatives --set x-terminal-emulator /usr/bin/alacritty 2>/dev/null || true

    if ! command_exists gsettings; then
        return
    fi

    # GNOME legacy default-applications (still respected by some handlers)
    gsettings set org.gnome.desktop.default-applications.terminal exec 'alacritty'    2>/dev/null || true
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg ''         2>/dev/null || true

    # Disable the built-in "launch terminal" binding so it doesn't race with our custom one
    gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "[]" 2>/dev/null || true

    # Re-bind Ctrl+Alt+T to Alacritty via a custom keybinding
    local base="org.gnome.settings-daemon.plugins.media-keys"
    local item="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
    local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/alacritty/"

    local existing
    existing=$(gsettings get "$base" custom-keybindings 2>/dev/null || echo "@as []")
    if [[ "$existing" != *"$path"* ]]; then
        if [ "$existing" = "@as []" ] || [ "$existing" = "[]" ]; then
            gsettings set "$base" custom-keybindings "['$path']"
        else
            gsettings set "$base" custom-keybindings "${existing%]}, '$path']"
        fi
    fi

    gsettings set "$item:$path" name    'Alacritty'
    gsettings set "$item:$path" command 'alacritty'
    gsettings set "$item:$path" binding '<Primary><Alt>t'
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

install_communication_apps() {
    print_status "Installing Discord and Slack (via Flatpak)"
    if ! command_exists flatpak; then
        echo "  Flatpak not available, skipping"
        return
    fi
    flatpak install -y flathub com.discordapp.Discord 2>/dev/null || echo "  Discord install failed"
    flatpak install -y flathub com.slack.Slack 2>/dev/null || echo "  Slack install failed"
}

install_whatsapp_for_linux() {
    print_status "Installing WhatsApp for Linux (himelrana apt mirror)"
    if dpkg -l whatsapp-linux 2>/dev/null | grep -q '^ii'; then
        echo "  WhatsApp for Linux is already installed"
        return
    fi

    local keyring=/usr/share/keyrings/himel.gpg
    local sources=/etc/apt/sources.list.d/himel-release.list
    local mirror="https://mirror.himelrana.com"

    if [ ! -f "$keyring" ]; then
        sudo curl -fsSLo "$keyring" "$mirror/himel.gpg"
    fi
    if [ ! -f "$sources" ]; then
        echo "deb [signed-by=$keyring] $mirror/ stable main" \
            | sudo tee "$sources" > /dev/null
        sudo apt update
    fi
    sudo apt install -y whatsapp-linux
}

install_claude_desktop() {
    print_status "Installing Claude Desktop (aaddrick/claude-desktop-debian)"
    if dpkg -l claude-desktop 2>/dev/null | grep -q '^ii'; then
        echo "  Claude Desktop is already installed"
        return
    fi

    # build.sh refuses to run as root — need a real user
    if [ "$(id -u)" -eq 0 ] && [ -z "$SUDO_USER" ]; then
        echo "  Running as root with no SUDO_USER — cannot build; skipping"
        return 1
    fi
    local target_user="${SUDO_USER:-$USER}"

    # Build deps documented upstream: 7z, wget, wrestool/icotool (icoutils), convert (imagemagick)
    sudo apt install -y p7zip-full wget icoutils imagemagick

    local repo=/tmp/claude-desktop-debian
    [ -d "$repo" ] && sudo rm -rf "$repo"

    if [ "$(id -u)" -eq 0 ]; then
        sudo -u "$target_user" git clone --depth 1 \
            https://github.com/aaddrick/claude-desktop-debian.git "$repo"
        sudo -u "$target_user" -H bash -c "cd '$repo' && ./build.sh" \
            || { echo "  build.sh failed"; return 1; }
    else
        git clone --depth 1 https://github.com/aaddrick/claude-desktop-debian.git "$repo"
        (cd "$repo" && ./build.sh) || { echo "  build.sh failed"; return 1; }
    fi

    local deb
    deb=$(find "$repo" -name 'claude-desktop_*.deb' -print -quit)
    if [ -z "$deb" ]; then
        echo "  Could not find built .deb in $repo"
        return 1
    fi
    sudo dpkg -i "$deb" || sudo apt-get install -f -y
    sudo rm -rf "$repo"
}

# Shared helper for Infomaniak AppImage apps (kDrive, kChat, kMeet).
# Downloads the AppImage to ~/.local/bin, extracts its icon, and writes a .desktop entry.
_install_infomaniak_appimage() {
    # Usage: _install_infomaniak_appimage <display-name> <slug> <url> [categories]
    local name="$1" slug="$2" url="$3" categories="${4:-Network;}"
    local bin_dir="$HOME/.local/bin"
    local app_dir="$HOME/.local/share/applications"
    local icon_dir="$HOME/.local/share/icons/hicolor/512x512/apps"
    local appimage="$bin_dir/${name}.AppImage"
    local desktop_file="$app_dir/${slug}.desktop"

    if [ -x "$appimage" ] && [ -f "$desktop_file" ]; then
        echo "  $name is already installed at $appimage"
        return
    fi

    mkdir -p "$bin_dir" "$app_dir" "$icon_dir"

    # AppImages need FUSE; Ubuntu 24.04 ships libfuse2t64, older releases use libfuse2
    sudo apt install -y libfuse2t64 2>/dev/null || sudo apt install -y libfuse2 2>/dev/null || true

    if [ ! -x "$appimage" ]; then
        curl -fL --max-time 600 -# -o "$appimage" "$url"
        chmod +x "$appimage"
    fi

    local extract_dir="/tmp/${slug}-extract"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    ( cd "$extract_dir" && "$appimage" --appimage-extract "${slug}.png" >/dev/null 2>&1 ) || true
    local extracted
    extracted=$(find "$extract_dir" -name "${slug}.png" -print -quit 2>/dev/null)
    [ -n "$extracted" ] && cp "$extracted" "$icon_dir/${slug}.png"
    rm -rf "$extract_dir"

    cat > "$desktop_file" << EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$appimage
Icon=$slug
Terminal=false
Categories=$categories
StartupWMClass=$name
EOF

    command_exists update-desktop-database && update-desktop-database "$app_dir" >/dev/null 2>&1 || true
}

install_kdrive() {
    print_status "Installing Infomaniak kDrive (official AppImage)"
    _install_infomaniak_appimage "kDrive" "kdrive" \
        "https://download.storage.infomaniak.com/drive/desktopclient/kDrive-x86_64.AppImage" \
        "Network;FileTransfer;"
}

install_kchat() {
    print_status "Installing Infomaniak kChat (official AppImage)"
    _install_infomaniak_appimage "kChat" "kchat" \
        "https://download.storage.infomaniak.com/kchat/desktop/kChat-x86_64.AppImage" \
        "Network;InstantMessaging;Chat;"
}

install_kmeet() {
    print_status "Installing Infomaniak kMeet (official AppImage)"
    _install_infomaniak_appimage "kMeet" "kmeet" \
        "https://download.storage.infomaniak.com/kmeet/desktop/kMeet-x86_64.AppImage" \
        "Network;Telephony;AudioVideo;"
}

install_onedriver() {
    print_status "Installing OneDriver (Microsoft OneDrive FUSE client)"
    if command_exists onedriver; then
        echo "  OneDriver is already installed"
        return
    fi

    # Upstream ships via openSUSE Build Service; pin to the current Ubuntu release
    local ubuntu_ver
    ubuntu_ver=$(lsb_release -rs 2>/dev/null || echo "24.04")
    local obs_repo="https://download.opensuse.org/repositories/home:jstaf/xUbuntu_${ubuntu_ver}"
    local keyring=/usr/share/keyrings/onedriver.gpg
    local sources=/etc/apt/sources.list.d/onedriver.list

    if [ ! -f "$keyring" ]; then
        curl -fsSL "$obs_repo/Release.key" | sudo gpg --dearmor -o "$keyring"
    fi
    if [ ! -f "$sources" ]; then
        echo "deb [signed-by=$keyring] $obs_repo/ /" | sudo tee "$sources" > /dev/null
        sudo apt update
    fi
    sudo apt install -y onedriver
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
COMMON_STEPS=(
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
    install_clever_tools
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
    install_modern_cli
    install_tmux
    setup_tmux_config
    install_git_polish
    install_rust
    install_dotnet
    install_go
    install_git_extras
    install_k8s_extras
    install_mkcert
    install_just
    install_cli_qol
    install_nerd_fonts
    setup_bash_completions
    manage_bash_aliases
    setup_bashrc
)
for step in "${COMMON_STEPS[@]}"; do
    run_step "$step"
done

# --- Native Ubuntu Desktop only ---
if ! is_wsl; then
    echo ""
    echo "=================================================="
    echo "🖥️  Installing desktop applications..."
    echo "=================================================="

    DESKTOP_STEPS=(
        install_brave
        install_edge
        install_mullvad_browser
        install_vscode
        install_alacritty
        set_alacritty_default
        install_gnome_extensions
        install_flatpak
        install_desktop_apps
        install_communication_apps
        install_whatsapp_for_linux
        install_claude_desktop
        install_kdrive
        install_kchat
        install_kmeet
        install_onedriver
        install_gtk_theme
        setup_gnome_terminal_font
        setup_keyboard_belgian
        setup_grub_resolution
        install_grub_theme
    )
    for step in "${DESKTOP_STEPS[@]}"; do
        run_step "$step"
    done

    if is_surface; then
        echo ""
        echo "=================================================="
        echo "💻 Microsoft Surface detected ($(cat /sys/class/dmi/id/product_name 2>/dev/null))"
        echo "=================================================="
        run_step install_surface_kernel
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
echo "   ✓ Clever Cloud CLI (clever-tools)"
echo "   ✓ direnv (auto-load .envrc per project)"
echo "   ✓ kubectl + k9s (Kubernetes CLI + terminal UI)"
echo "   ✓ Helm (Kubernetes package manager)"
echo "   ✓ Ollama (local LLMs)"
echo "   ✓ uv (fast Python package manager)"
echo "   ✓ Bun (JavaScript runtime & package manager)"
echo "   ✓ SDKMAN + OpenJDK 25 (Temurin)"
echo "   ✓ typescript-language-server (TypeScript LSP)"
echo "   ✓ jdtls (Eclipse Java LSP)"
echo "   ✓ Modern CLI: ripgrep, fd, bat, eza, fzf, zoxide"
echo "   ✓ tmux (terminal multiplexer) + managed ~/.tmux.conf + TPM + plugins (sensible, resurrect, continuum)"
echo "   ✓ git-delta + lazygit (git diff/TUI)"
echo "   ✓ git-lfs + pre-commit (git workflow)"
echo "   ✓ Rust toolchain (rustup, cargo, rustc)"
echo "   ✓ Go toolchain (latest from go.dev)"
echo "   ✓ .NET SDK 10"
echo "   ✓ kubectx + kubens + stern (K8s QoL)"
echo "   ✓ mkcert (local HTTPS CA)"
echo "   ✓ just (task runner)"
echo "   ✓ btop, tldr, hyperfine (CLI QoL)"
echo "   ✓ Nerd Fonts (FiraCode, JetBrainsMono, Meslo, Hack — with icons)"
echo "   ✓ Enhanced bash completion for all tools"
echo "   ✓ Bash aliases (p=pnpm, y=yarn, c=clear, g=git, k=kubectl, pod/docker=podman, bat, fd, lg)"
echo "   ✓ ~/repos workspace directory"

if ! is_wsl; then
    echo ""
    echo "🖥️  Desktop components:"
    echo "   ✓ Brave browser"
    echo "   ✓ Microsoft Edge"
    echo "   ✓ Mullvad Browser"
    echo "   ✓ Visual Studio Code"
    echo "   ✓ Alacritty (GPU-accelerated terminal; managed config auto-launches tmux) — set as default, Ctrl+Alt+T rebound"
    echo "   ✓ GNOME Tweaks + Extension Manager"
    echo "   ✓ Dash to Panel + GSConnect extensions"
    echo "   ✓ Flatpak + Flathub"
    echo "   ✓ VLC, GIMP, Evince (PDF), Shotcut (video), Sound Recorder"
    echo "   ✓ Discord, Slack (Flatpak)"
    echo "   ✓ WhatsApp for Linux (himelrana apt mirror)"
    echo "   ✓ Claude Desktop (aaddrick .deb build)"
    echo "   ✓ Infomaniak kDrive, kChat, kMeet (official AppImages + .desktop entries)"
    echo "   ✓ OneDriver (Microsoft OneDrive FUSE client)"
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

if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
    echo ""
    echo "=================================================="
    echo "⚠️  ${#FAILED_STEPS[@]} step(s) reported failure:"
    echo "=================================================="
    for step in "${FAILED_STEPS[@]}"; do
        echo "   - $step"
    done
    echo ""
    echo "   Re-run the script to retry, or invoke the individual function"
    echo "   (e.g. 'bash -c \"source ./setup.sh; install_glab\"') to debug."
fi

echo ""
echo "📋 Script completed at: $(date)"

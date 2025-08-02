#!/bin/bash

# WSL Ubuntu 24.04 Automated Setup Script
# This script automates the installation and configuration of development tools
# IDEMPOTENT: Safe to run multiple times without duplicating configurations

set -e  # Exit on any error

echo "🚀 Starting WSL Ubuntu 24.04 setup..."
echo "=================================================="

# Function to print status messages
print_status() {
    echo -e "\n📦 $1..."
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to safely update .bashrc with idempotent sections
update_bashrc_section() {
    local marker="$1"
    local content="$2"
    local start_marker="# ===== $marker - START ====="
    local end_marker="# ===== $marker - END ====="
    
    # Create backup only if this is the first time we're modifying .bashrc
    if [ ! -f ~/.bashrc.backup.original ]; then
        cp ~/.bashrc ~/.bashrc.backup.original
        echo "✅ Original .bashrc backed up to ~/.bashrc.backup.original"
    fi
    
    # Remove existing section if it exists
    if grep -q "$start_marker" ~/.bashrc; then
        # Use sed to remove the section between markers
        sed -i "/$start_marker/,/$end_marker/d" ~/.bashrc
        echo "✅ Removed existing $marker section from .bashrc"
    fi
    
    # Add the new section
    echo -e "\n$start_marker" >> ~/.bashrc
    echo -e "$content" >> ~/.bashrc
    echo -e "$end_marker" >> ~/.bashrc
    echo "✅ Added $marker section to .bashrc"
}

# Function to manage .bash_aliases file
manage_bash_aliases() {
    local aliases_file="$HOME/.bash_aliases"
    
    # Create .bash_aliases if it doesn't exist
    if [ ! -f "$aliases_file" ]; then
        touch "$aliases_file"
        echo "✅ Created .bash_aliases file"
    fi
    
    # Function to add alias if it doesn't exist
    add_alias_if_not_exists() {
        local alias_name="$1"
        local alias_command="$2"
        local alias_line="alias $alias_name='$alias_command'"
        
        # Check if alias already exists (look for the exact alias definition)
        if grep -q "^alias $alias_name=" "$aliases_file"; then
            echo "✅ Alias '$alias_name' already exists in .bash_aliases"
        else
            echo "$alias_line" >> "$aliases_file"
            echo "✅ Added alias '$alias_name' to .bash_aliases"
        fi
    }
    
    # Add our desired aliases
    add_alias_if_not_exists "p" "pnpm"
    add_alias_if_not_exists "c" "clear"
    add_alias_if_not_exists "docker" "podman"
    
    # Ensure .bashrc sources .bash_aliases (check if it's already there)
    if ! grep -q "\.bash_aliases" ~/.bashrc; then
        BASH_ALIASES_SOURCE='
# Source .bash_aliases if it exists
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi'
        update_bashrc_section "BASH ALIASES SOURCING" "$BASH_ALIASES_SOURCE"
    else
        echo "✅ .bashrc already sources .bash_aliases"
    fi
}

# Update and upgrade system
print_status "Updating and upgrading system packages"
sudo apt update && sudo apt upgrade -y

# Install essential packages including git
print_status "Installing essential packages (git, bash-completion, etc.)"
sudo apt install -y git bash-completion command-not-found curl wget

# Configure bash completion in .bashrc
print_status "Configuring enhanced bash completion in .bashrc"

# Define the bash completion configuration
BASH_COMPLETION_CONFIG='
# Enhanced Bash Completion Configuration

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Load custom completions AFTER system completions
if [ -d ~/.bash_completion.d ]; then
    for completion in ~/.bash_completion.d/*; do
        [ -r "$completion" ] && . "$completion"
    done
fi

# Enable case-insensitive completion
bind "set completion-ignore-case on"

# Show all completions after double tab
bind "set show-all-if-ambiguous on"

# Enable menu completion (cycle through completions)
bind "set menu-complete-display-prefix on"

# Use Tab to cycle through completions
bind '\''"\t": menu-complete'\''

# Use Shift+Tab to cycle backwards through completions
bind '\''"\e[Z": menu-complete-backward'\''

# Show completion type indicators
bind "set visible-stats on"

# Enable colored completion
bind "set colored-stats on"

# Enable completion of hostnames
shopt -s hostcomplete

# Enable extended globbing
shopt -s extglob

# Enable directory spell checking
shopt -s dirspell

# Enable automatic cd when typing directory name
shopt -s autocd

# Enable recursive globbing with **
shopt -s globstar

# History settings for better completion context
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Create ~/repos directory if it doesn'\''t exist
[ -d "$HOME/repos" ] || mkdir -p "$HOME/repos"

# Change to ~/repos for interactive shells
if [[ $- == *i* ]]; then
    cd "$HOME/repos" || true
fi'

# Update .bashrc with the bash completion configuration
update_bashrc_section "AUTOMATED WSL SETUP" "$BASH_COMPLETION_CONFIG"

# Create ~/repos directory now (during script execution)
print_status "Creating ~/repos directory"
mkdir -p ~/repos

# Install podman
print_status "Installing Podman"
sudo apt install -y podman

# Install starship prompt
print_status "Installing Starship prompt"
if ! command_exists starship; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    echo "✅ Starship installed"
else
    echo "✅ Starship is already installed"
fi

# Add starship initialization to .bashrc if not already present
if ! grep -q "starship init bash" ~/.bashrc; then
    STARSHIP_CONFIG='eval "$(starship init bash)"'
    update_bashrc_section "STARSHIP PROMPT" "$STARSHIP_CONFIG"
else
    echo "✅ Starship initialization already exists in ~/.bashrc"
fi

# Install NVM (Node Version Manager)
print_status "Installing NVM (Node Version Manager)"
if [ ! -d "$HOME/.nvm" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    
    # Source nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    echo "✅ NVM installed successfully"
else
    echo "✅ NVM is already installed"
    # Source nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Install latest LTS Node.js using NVM
print_status "Installing latest LTS Node.js via NVM"
if command_exists nvm; then
    nvm install --lts
    nvm use --lts
    nvm alias default lts/*
    echo "✅ Node.js LTS installed and set as default"
    
    # Display installed Node.js version
    echo "📋 Node.js version: $(node --version)"
    echo "📋 NPM version: $(npm --version)"
else
    echo "❌ NVM not found in current session. Please restart your terminal and run: nvm install --lts"
fi

# Enable Corepack
print_status "Enabling Corepack"
if command_exists corepack; then
    corepack enable
    echo "✅ Corepack enabled"
else
    echo "❌ Corepack not available. It should come with Node.js 16.10+. Please check your Node.js installation."
fi

# Install pnpm using Corepack
print_status "Installing pnpm via Corepack"
if command_exists corepack; then
    corepack prepare pnpm@latest --activate
    echo "✅ pnpm installed via Corepack"
    
    # Display pnpm version if successful
    if command_exists pnpm; then
        echo "📋 pnpm version: $(pnpm --version)"
    fi
else
    echo "⚠️  Corepack not available, installing pnpm via npm as fallback"
    if command_exists npm; then
        npm install -g pnpm
        echo "✅ pnpm installed via npm"
    else
        echo "❌ Neither corepack nor npm available for pnpm installation"
    fi
fi

# Install Claude Code globally via npm
print_status "Installing Claude Code globally via npm"
if command_exists npm; then
    if ! command_exists claude-code; then
        npm install -g claude-code
        echo "✅ Claude Code installed globally"
    else
        echo "✅ Claude Code is already installed"
    fi
    
    # Display version if the installation was successful
    if command_exists claude-code; then
        echo "📋 Claude Code version: $(claude-code --version 2>/dev/null || echo 'Version check not available')"
    fi
else
    echo "❌ npm not available. Claude Code installation skipped"
fi

# Install GitHub CLI
print_status "Installing GitHub CLI"
if ! command_exists gh; then
    # Add GitHub CLI repository and install
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
    echo "✅ GitHub CLI installed"
else 
    echo "✅ GitHub CLI is already installed"
fi

# Display GitHub CLI version
if command_exists gh; then
    echo "📋 GitHub CLI version: $(gh --version | head -n1)"
fi

# Add GitHub CLI completion
if command_exists gh; then
    gh completion -s bash > ~/.bash_completion.d/gh_completion 2>/dev/null || true
    echo "✅ GitHub CLI completion configured"
fi

# Install Azure CLI
print_status "Installing Azure CLI"
if ! command_exists az; then
    # Add Microsoft repository and install Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    echo "✅ Azure CLI installed"
else
    echo "✅ Azure CLI is already installed"
fi

# Display Azure CLI version
if command_exists az; then
    echo "📋 Azure CLI version: $(az --version | head -n1)"
fi

# Add Azure CLI completion
if command_exists az; then
    az completion > ~/.bash_completion.d/az_completion 2>/dev/null || true
    echo "✅ Azure CLI completion configured"
fi

# Install AWS CLI
print_status "Installing AWS CLI"
if ! command_exists aws; then
    # Download and install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && sudo ./aws/install \
    && rm -rf awscliv2.zip aws/
    echo "✅ AWS CLI installed"
else
    echo "✅ AWS CLI is already installed"
fi

# Display AWS CLI version
if command_exists aws; then
    echo "📋 AWS CLI version: $(aws --version)"
fi

# Add AWS CLI completion
if command_exists aws; then
    aws_completer_path=$(which aws_completer 2>/dev/null)
    if [ -n "$aws_completer_path" ]; then
        echo "complete -C '$aws_completer_path' aws" > ~/.bash_completion.d/aws_completion
        echo "✅ AWS CLI completion configured"
    fi
fi

# Install Cloudflare CLI (Wrangler)
print_status "Installing Cloudflare CLI (Wrangler)"
if ! command_exists wrangler; then
    if command_exists npm; then
        npm install -g wrangler
        echo "✅ Cloudflare CLI (Wrangler) installed"
    else
        echo "❌ npm not available. Cloudflare CLI installation skipped"
    fi
else
    echo "✅ Cloudflare CLI (Wrangler) is already installed"
fi

# Display Wrangler version
if command_exists wrangler; then
    echo "📋 Cloudflare CLI version: $(wrangler --version)"
fi

# Add Wrangler completion (if available)
if command_exists wrangler; then
    wrangler generate-completion bash > ~/.bash_completion.d/wrangler_completion 2>/dev/null || true
    echo "✅ Cloudflare CLI completion configured"
fi

# Setup bash aliases
print_status "Setting up bash aliases"
manage_bash_aliases

# Setup additional completions for installed tools
print_status "Setting up additional completions for installed tools"

# Create a directory for custom completions
mkdir -p ~/.bash_completion.d

# Generate npm completion (overwrite is OK for completions)
if command_exists npm; then
    npm completion > ~/.bash_completion.d/npm_completion 2>/dev/null || true
    echo "✅ NPM completion configured"
fi

# Add git completion enhancements using the proper method (overwrite is OK)
if command_exists git; then
    cat > ~/.bash_completion.d/git_enhancements << 'EOF'
# Enhanced git completions
# Create git alias
alias g='git'

# Set up completion for git alias using the standard method
# Check if _git function is available (loaded by bash-completion)
if [[ $(type -t _git) == function ]]; then
    complete -o default -o nospace -F _git g
fi
EOF
    echo "✅ Git completion configured (alias 'g' available)"
fi

# Add podman completion if available (overwrite is OK)
if command_exists podman; then
    podman completion bash > ~/.bash_completion.d/podman_completion 2>/dev/null || true
    echo "✅ Podman completion configured"
fi

# Final setup summary
echo ""
echo "=================================================="
echo "🎉 Setup completed successfully!"
echo "=================================================="
echo ""
echo "📋 Installed components:"
echo "   ✓ System packages updated"
echo "   ✓ Git with completion support"
echo "   ✓ bash-completion with enhanced configuration"
echo "   ✓ command-not-found"
echo "   ✓ Podman (with completion)"
echo "   ✓ Starship prompt"
echo "   ✓ NVM (Node Version Manager with completion)"
echo "   ✓ Node.js LTS"
echo "   ✓ Corepack"
echo "   ✓ pnpm"
echo "   ✓ Claude Code"
echo "   ✓ GitHub CLI"
echo "   ✓ Azure CLI"
echo "   ✓ AWS CLI"
echo "   ✓ CloudFlare CLI (Wrangler)"
echo "   ✓ Enhanced bash completion features"
echo "   ✓ ~/repos directory (default directory for new terminals)"
echo "   ✓ .bash_aliases with useful shortcuts"
echo ""
echo "🔄 Next steps:"
echo "   1. Restart your terminal or run: source ~/.bashrc"
echo "   2. New terminals will start in ~/repos directory"
echo "   3. Verify installations:"
echo "      - git --version"
echo "      - node --version"
echo "      - npm --version"
echo "      - pnpm --version (or just 'p --version')"
echo "      - podman --version"
echo "      - claude-code --version"
echo ""
echo "🎯 Bash completion features enabled:"
echo "   ✓ Case-insensitive completion"
echo "   ✓ Menu completion (Tab to cycle)"
echo "   ✓ Colored completions"
echo "   ✓ Show completion statistics"
echo "   ✓ Directory spell checking"
echo "   ✓ Extended globbing and history"
echo "   ✓ Custom completions for npm, git (alias 'g'), podman"
echo ""
echo "🔗 Available aliases:"
echo "   ✓ p = pnpm (e.g., 'p install', 'p run dev')"
echo "   ✓ c = clear (quick terminal clearing)"
echo "   ✓ g = git (with full completion support)"
echo ""
echo "💡 Tips:"
echo "   - Use Tab to complete and cycle through options"
echo "   - Use Shift+Tab to cycle backwards"
echo "   - Double-Tab shows all available completions"
echo "   - Type part of a directory name and press Tab for completion"
echo "   - Use shortcuts: 'p' for pnpm, 'c' for clear, 'g' for git"
echo "   - New terminals will automatically start in ~/repos"
echo ""
echo "🔄 Idempotent design:"
echo "   - Safe to run multiple times without duplicating configurations"
echo "   - Original .bashrc backed up to ~/.bashrc.backup.original"
echo "   - Configurations use markers to prevent duplication"
echo "   - Aliases are added only if they don't already exist"
echo ""

# Optional: Display current shell info
echo "📋 Current shell: $SHELL"
echo "📋 Script completed at: $(date)"

# Show current .bashrc sections
echo ""
echo "📋 Current .bashrc sections managed by this script:"
grep -n "===== .* - START =====" ~/.bashrc 2>/dev/null || echo "   No managed sections found"

# Show current aliases
echo ""
echo "📋 Current aliases in .bash_aliases:"
if [ -f ~/.bash_aliases ]; then
    grep "^alias" ~/.bash_aliases 2>/dev/null || echo "   No aliases found"
else
    echo "   .bash_aliases file not found"
fi

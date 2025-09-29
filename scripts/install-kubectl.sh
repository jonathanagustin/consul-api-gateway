#!/usr/bin/env bash

set -e

echo "kubectl Installation Script"
echo "==========================="
echo ""

# Check if kubectl is already installed
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl is already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | grep gitVersion | head -1 | cut -d: -f2)"
    exit 0
fi

echo "kubectl is not installed. Installing..."
echo ""

# Detect OS and Architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Linux*)     OS_TYPE=linux;;
    Darwin*)    OS_TYPE=darwin;;
    CYGWIN*|MINGW*) OS_TYPE=windows;;
    *)          OS_TYPE="UNKNOWN"
esac

case "${ARCH}" in
    x86_64)     ARCH_TYPE=amd64;;
    aarch64)    ARCH_TYPE=arm64;;
    arm64)      ARCH_TYPE=arm64;;
    armv7l)     ARCH_TYPE=arm;;
    386)        ARCH_TYPE=386;;
    *)          ARCH_TYPE="${ARCH}"
esac

echo "Detected OS: ${OS} (${OS_TYPE})"
echo "Detected Architecture: ${ARCH} (${ARCH_TYPE})"

if [[ "$OS_TYPE" == "UNKNOWN" ]]; then
    echo "✗ Unsupported operating system: ${OS}"
    echo "  Please install kubectl manually: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Get latest stable version
echo ""
echo "Getting latest stable kubectl version..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
echo "Latest version: ${KUBECTL_VERSION}"

# Download kubectl
echo ""
echo "Downloading kubectl ${KUBECTL_VERSION} for ${OS_TYPE}/${ARCH_TYPE}..."
DOWNLOAD_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS_TYPE}/${ARCH_TYPE}/kubectl"

if command -v wget &> /dev/null; then
    wget -q --show-progress -O /tmp/kubectl "$DOWNLOAD_URL"
elif command -v curl &> /dev/null; then
    curl -LO --progress-bar --output-dir /tmp "$DOWNLOAD_URL"
else
    echo "✗ Neither wget nor curl found. Please install one of them first."
    exit 1
fi

# Verify download (optional but recommended)
echo ""
echo "Verifying kubectl binary..."
if command -v sha256sum &> /dev/null || command -v shasum &> /dev/null; then
    # Download checksum
    curl -LO --silent --output-dir /tmp "https://dl.k8s.io/${KUBECTL_VERSION}/bin/${OS_TYPE}/${ARCH_TYPE}/kubectl.sha256"
    
    # Verify checksum
    if command -v sha256sum &> /dev/null; then
        echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check --status
    else
        echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | shasum -a 256 --check --status
    fi
    
    if [ $? -eq 0 ]; then
        echo "✓ Checksum verification passed"
    else
        echo "✗ Checksum verification failed!"
        echo "  The downloaded file may be corrupted or tampered with."
        rm -f /tmp/kubectl /tmp/kubectl.sha256
        exit 1
    fi
    rm -f /tmp/kubectl.sha256
else
    echo "⚠ Skipping checksum verification (sha256sum/shasum not found)"
fi

# Make kubectl executable
chmod +x /tmp/kubectl

# Install kubectl
echo ""
echo "Installing kubectl..."

# Try to install system-wide first (requires sudo)
if sudo -n true 2>/dev/null; then
    # Can use sudo without password
    sudo mv /tmp/kubectl /usr/local/bin/kubectl
    echo "✓ Installed to /usr/local/bin/kubectl"
else
    # Try with sudo prompt
    echo "Installing kubectl requires sudo access to install to /usr/local/bin"
    echo "You can also install to your home directory if you prefer."
    read -p "Install system-wide with sudo? [Y/n]: " -r
    if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
        sudo mv /tmp/kubectl /usr/local/bin/kubectl
        echo "✓ Installed to /usr/local/bin/kubectl"
    else
        # Install to user's home directory
        mkdir -p ~/.local/bin
        mv /tmp/kubectl ~/.local/bin/kubectl
        echo "✓ Installed to ~/.local/bin/kubectl"
        
        # Check if ~/.local/bin is in PATH
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo ""
            echo "⚠ WARNING: ~/.local/bin is not in your PATH"
            echo "  Add this line to your ~/.bashrc or ~/.zshrc:"
            echo ""
            echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
            echo ""
            echo "  Then reload your shell or run: source ~/.bashrc"
        fi
    fi
fi

# Verify installation
echo ""
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl installed successfully!"
    echo "  Version: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | grep gitVersion | head -1 | cut -d: -f2)"
    
    # Enable bash completion if possible
    if [ -n "$BASH_VERSION" ] && [ -f /etc/bash_completion ]; then
        echo ""
        echo "Enabling bash completion for kubectl..."
        kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
        echo "✓ Bash completion enabled"
    fi
else
    echo "✗ kubectl installation failed or not in PATH"
    echo "  Please check your PATH environment variable"
    exit 1
fi

echo ""
echo "Installation complete!"
echo "You can now use kubectl to interact with Kubernetes clusters."
echo ""
echo "Quick test commands:"
echo "  kubectl version --client"
echo "  kubectl cluster-info"
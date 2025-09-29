#!/usr/bin/env bash

set -e

echo "Helm Installation Script"
echo "========================"
echo ""

# Check if helm is already installed
if command -v helm &> /dev/null; then
    echo "✓ Helm is already installed: $(helm version --short)"
    exit 0
fi

echo "Helm is not installed. Installing..."
echo ""

# Detect OS and Architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
    Linux*)     OS_TYPE=linux;;
    Darwin*)    OS_TYPE=darwin;;
    *)          OS_TYPE="UNKNOWN"
esac

case "${ARCH}" in
    x86_64)     ARCH_TYPE=amd64;;
    aarch64)    ARCH_TYPE=arm64;;
    arm64)      ARCH_TYPE=arm64;;
    *)          ARCH_TYPE="${ARCH}"
esac

echo "Detected OS: ${OS} (${OS_TYPE})"
echo "Detected Architecture: ${ARCH} (${ARCH_TYPE})"

if [[ "$OS_TYPE" == "UNKNOWN" ]]; then
    echo "✗ Unsupported operating system: ${OS}"
    echo "  Please install Helm manually: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Install Helm using the official script
echo ""
echo "Downloading and installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Clean up
rm -f get_helm.sh

# Verify installation
if command -v helm &> /dev/null; then
    echo ""
    echo "✓ Helm installed successfully!"
    echo "  Version: $(helm version --short)"
    
    # Add common repos
    echo ""
    echo "Adding common Helm repositories..."
    helm repo add stable https://charts.helm.sh/stable 2>/dev/null || true
    helm repo update
    
    echo ""
    echo "Available repositories:"
    helm repo list
else
    echo "✗ Helm installation failed"
    echo "  Please try manual installation: https://helm.sh/docs/intro/install/"
    exit 1
fi

echo ""
echo "Installation complete!"
echo "You can now deploy charts with: helm install [NAME] [CHART]"
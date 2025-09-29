#!/usr/bin/env bash

set -e

echo "k3d Installation Script"
echo "======================"
echo ""

# Check if k3d is already installed
if command -v k3d &> /dev/null; then
    echo "✓ k3d is already installed: $(k3d version)"
    exit 0
fi

echo "k3d is not installed. Installing..."
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     OS_TYPE=Linux;;
    Darwin*)    OS_TYPE=Mac;;
    *)          OS_TYPE="UNKNOWN:${OS}"
esac

echo "Detected OS: ${OS_TYPE}"

# Install k3d
if [[ "$OS_TYPE" == "Linux" ]] || [[ "$OS_TYPE" == "Mac" ]]; then
    echo "Downloading and installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    
    # Verify installation
    if command -v k3d &> /dev/null; then
        echo ""
        echo "✓ k3d installed successfully!"
        echo "  Version: $(k3d version)"
    else
        echo "✗ k3d installation failed"
        echo "  Please try manual installation: https://k3d.io/stable/#installation"
        exit 1
    fi
else
    echo "✗ Unsupported operating system: ${OS_TYPE}"
    echo "  Please install k3d manually: https://k3d.io/stable/#installation"
    exit 1
fi

echo ""
echo "Installation complete!"
echo "You can now create a cluster with: k3d cluster create"
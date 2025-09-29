#!/usr/bin/env bash

set -e

# Parse command line arguments
AUTO_APPROVE=false
for arg in "$@"; do
    case $arg in
        -y|--yes)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -y, --yes    Auto-approve all prompts (non-interactive mode)"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
    esac
done

echo "Cluster destroy script"
echo "======================"

# Check if k3d cluster exists
if k3d cluster list 2>/dev/null | grep -q "k3s-default"; then
    echo "Found k3d cluster: k3s-default"
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        REPLY="y"
    else
        read -p "Delete the cluster? [Y/n]: " -r
    fi
    if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting k3d cluster..."
        k3d cluster delete k3s-default
        echo "Cluster deleted"
    else
        echo "Keeping cluster"
    fi
else
    echo "No k3d cluster found"
fi

echo ""
echo "Note: To remove cluster.local from /etc/hosts, run: sudo ./scripts/cleanup.sh"
echo ""
echo "Destroy complete!"
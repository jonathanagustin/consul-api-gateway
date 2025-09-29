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

echo "Host cleanup script"
echo "==================="
echo ""

# Check what cluster.local entries exist
ipv4_entries=$(grep "^127.0.0.1.*cluster.local" /etc/hosts 2>/dev/null || true)
ipv6_entries=$(grep "^::1.*cluster.local" /etc/hosts 2>/dev/null || true)

if [[ -z "$ipv4_entries" ]] && [[ -z "$ipv6_entries" ]]; then
    echo "✓ No cluster.local entries found in /etc/hosts"
    echo ""
    echo "Cleanup complete!"
    exit 0
fi

echo "Found the following cluster.local entries in /etc/hosts:"
echo ""
if [[ ! -z "$ipv4_entries" ]]; then
    echo "IPv4 entries:"
    echo "$ipv4_entries" | sed 's/^/  /'
fi
if [[ ! -z "$ipv6_entries" ]]; then
    echo "IPv6 entries:"
    echo "$ipv6_entries" | sed 's/^/  /'
fi
echo ""

if [[ "$AUTO_APPROVE" == "true" ]]; then
    REPLY="y"
else
    read -p "Remove ALL cluster.local entries from /etc/hosts? [Y/n]: " -r
fi

if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Removing cluster.local entries from /etc/hosts (requires sudo)..."
    
    # Count entries before removal
    count_before=$(grep -c "cluster.local" /etc/hosts || true)
    
    # Remove all cluster.local entries
    sudo sed -i '/cluster.local/d' /etc/hosts
    
    # Verify removal
    count_after=$(grep -c "cluster.local" /etc/hosts || true)
    removed=$((count_before - count_after))
    
    echo "✓ Removed $removed cluster.local entries from /etc/hosts"
else
    echo "Keeping hosts entries"
fi

echo "Cleanup complete!"

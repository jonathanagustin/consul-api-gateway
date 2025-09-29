#!/usr/bin/env bash

set -e

echo "Hosts Setup Script"
echo "=================="
echo ""

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

# Check what needs to be added
needs_update=false
entries_to_add_ipv4=()
entries_to_add_ipv6=()

# Check IPv4 entries
if ! grep -q "^127.0.0.1.*cluster.local" /etc/hosts 2>/dev/null; then
    entries_to_add_ipv4+=("cluster.local")
    needs_update=true
fi

if ! grep -q "^127.0.0.1.*www.cluster.local" /etc/hosts 2>/dev/null; then
    entries_to_add_ipv4+=("www.cluster.local")
    needs_update=true
fi

# Check IPv6 entries
if ! grep -q "^::1.*cluster.local" /etc/hosts 2>/dev/null; then
    entries_to_add_ipv6+=("cluster.local")
    needs_update=true
fi

if ! grep -q "^::1.*www.cluster.local" /etc/hosts 2>/dev/null; then
    entries_to_add_ipv6+=("www.cluster.local")
    needs_update=true
fi

if [[ "$needs_update" == "false" ]]; then
    echo "✓ All hosts entries already configured:"
    grep cluster.local /etc/hosts
    exit 0
fi

echo "The following entries need to be added to /etc/hosts:"
for entry in "${entries_to_add_ipv4[@]}"; do
    echo "  - 127.0.0.1 $entry"
done
for entry in "${entries_to_add_ipv6[@]}"; do
    echo "  - ::1 $entry"
done
echo ""

if [[ "$AUTO_APPROVE" == "false" ]]; then
    read -p "Add these entries to /etc/hosts? [Y/n]: " -r
    if [[ ! -z $REPLY && ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 1
    fi
fi

# Add entries with sudo
echo "Adding entries to /etc/hosts (requires sudo)..."

# Add IPv4 entries
for entry in "${entries_to_add_ipv4[@]}"; do
    echo "127.0.0.1 $entry" | sudo tee -a /etc/hosts > /dev/null
    echo "✓ Added: 127.0.0.1 $entry"
done

# Add IPv6 entries  
for entry in "${entries_to_add_ipv6[@]}"; do
    echo "::1 $entry" | sudo tee -a /etc/hosts > /dev/null
    echo "✓ Added: ::1 $entry"
done

echo ""
echo "Setup complete! Current cluster.local entries:"
grep cluster.local /etc/hosts
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

# Setup hosts entries
"$(dirname "$0")/setup-hosts.sh" $(if [[ "$AUTO_APPROVE" == "true" ]]; then echo "--yes"; fi)

# Check if k3d is installed
if ! command -v k3d &> /dev/null; then
    echo "k3d is not installed"
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        REPLY="y"
    else
        read -p "Install k3d? [Y/n]: " -r
    fi
    if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
        "$(dirname "$0")/install-k3d.sh"
    else
        echo "Cannot proceed without k3d. Exiting."
        echo "You can install it manually with: ./scripts/install-k3d.sh"
        exit 1
    fi
else
    echo "k3d is already installed: $(k3d version)"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed"
    echo "kubectl comes with k3d and should be available after k3d installation"
    echo "Please ensure k3d is properly installed first"
    exit 1
else
    echo "kubectl is available: $(kubectl version --client --short 2>/dev/null || echo 'version info unavailable')"
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "helm is not installed"
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        REPLY="y"
    else
        read -p "Install helm? [Y/n]: " -r
    fi
    if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
        "$(dirname "$0")/install-helm.sh"
    else
        echo "Cannot proceed without helm. Exiting."
        echo "You can install it manually with: ./scripts/install-helm.sh"
        exit 1
    fi
else
    echo "helm is already installed: $(helm version --short)"
fi

# Check if cluster exists
if k3d cluster list | grep -q "k3s-default"; then
    echo "Cluster k3s-default already exists"
else
    echo "Creating k3d cluster..."
    k3d cluster create --config k3d-config.yaml
fi

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=600s

# Deploy infrastructure components
echo "Deploying Consul and API Gateway..."
kubectl apply -f crds/standard-install.yaml
kubectl config set-context --current --namespace=consul
helm upgrade --install consul consul/ --create-namespace -n consul -f consul/override-values.yaml --wait=false
helm upgrade --install api-gateway api-gateway/ --namespace consul --create-namespace --wait=false

echo "Waiting for Consul to be ready..."
kubectl wait --for=condition=ready pod -l component=server -n consul --timeout=900s || true
kubectl wait --for=condition=ready pod -l component=connect-injector -n consul --timeout=900s || true

echo "Waiting for API Gateway to be ready..."
# Wait for the gateway deployment to be available
kubectl wait --for=condition=available deployment/api-gateway -n consul --timeout=300s || true

# Deploy example application
echo "Deploying example application..."
kubectl config set-context --current --namespace=example-app
helm upgrade --install example-app ./example-app --namespace example-app --create-namespace --wait=false
kubectl wait --for=condition=available deployment/example-app -n example-app --timeout=300s

echo ""
echo "Running validation checks..."
echo "============================"
if "$(dirname "$0")/validate.sh"; then
    echo ""
    echo "🎉 Setup complete and validated!"
    echo ""
    echo "Access the application:"
    echo "  Browser: http://www.cluster.local"
    echo "  CLI:     curl -H \"Host: www.cluster.local\" http://localhost/"
else
    echo ""
    echo "⚠️  Setup complete but validation failed"
    echo "Run ./scripts/validate.sh for details"
fi
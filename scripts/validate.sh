#!/usr/bin/env bash

set -e

echo "Consul API Gateway Validation"
echo "============================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
VALIDATION_PASSED=true

# Function to check a condition
check() {
    local description="$1"
    local command="$2"
    
    echo -n "Checking: $description... "
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        VALIDATION_PASSED=false
        return 1
    fi
}

# Function to check with output
check_with_output() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "Checking: $description... "
    local output=$(eval "$command" 2>/dev/null || true)
    if [[ "$output" == *"$expected"* ]]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} (expected: $expected, got: $output)"
        VALIDATION_PASSED=false
        return 1
    fi
}

echo "Prerequisites:"
echo "--------------"
check "kubectl installed" "command -v kubectl"
check "helm installed" "command -v helm"
check "k3d installed" "command -v k3d"
echo ""

echo "Cluster Status:"
echo "---------------"
check "k3d cluster exists" "k3d cluster list | grep -q k3s-default"
check "kubectl context set" "kubectl config current-context | grep -q k3d-k3s-default"
check "cluster nodes ready" "kubectl get nodes | grep -q Ready"
echo ""

echo "Consul Components:"
echo "------------------"
check "Consul namespace exists" "kubectl get ns consul"
check "Consul server running" "kubectl get pod -n consul -l component=server --no-headers | grep -q Running"
check "Connect injector running" "kubectl get pod -n consul -l component=connect-injector --no-headers | grep -q Running"
check "Gateway controller running" "kubectl get pod -n consul -l component=gateway-controller --no-headers 2>/dev/null | grep -q Running || kubectl get pod -n consul -l component=connect-injector --no-headers | grep -q Running"
echo ""

echo "API Gateway:"
echo "------------"
check "Gateway CRDs installed" "kubectl get crd gateways.gateway.networking.k8s.io"
check "Gateway resource exists" "kubectl get gateway -n consul api-gateway"
check "Gateway pod running" "kubectl get pod -n consul | grep api-gateway | grep -q Running"
check "Gateway service exists" "kubectl get svc -n consul api-gateway"
echo ""

echo "Example Application:"
echo "--------------------"
check "Example-app namespace exists" "kubectl get ns example-app"
check "Example-app deployment exists" "kubectl get deployment -n example-app example-app"
check "Example-app pod running (2/2 containers)" "kubectl get pod -n example-app -l app=example-app --no-headers | grep -q '2/2.*Running'"
check "Service exists" "kubectl get svc -n example-app example-app"
check "HTTPRoute exists" "kubectl get httproute -n example-app example-app-route"
check "HTTPRoute accepted" "kubectl get httproute -n example-app example-app-route -o jsonpath='{.status.parents[0].conditions[?(@.type==\"Accepted\")].status}' | grep -q True"
echo ""

echo "Service Mesh Configuration:"
echo "---------------------------"
check "ServiceDefaults exists" "kubectl get servicedefaults -n example-app example-app"
check "ServiceIntentions exists" "kubectl get serviceintentions -n example-app example-app"
check "ReferenceGrant exists" "kubectl get referencegrant -n consul example-app-gateway-ref"
echo ""

echo "Network Configuration:"
echo "----------------------"
check "Hosts entry for cluster.local" "grep -q cluster.local /etc/hosts"
check "Hosts entry for www.cluster.local" "grep -q www.cluster.local /etc/hosts"
echo ""

echo "Connectivity Test:"
echo "------------------"
echo -n "Testing HTTP endpoint... "
if curl -s -o /dev/null -w "%{http_code}" -H "Host: www.cluster.local" http://localhost/ | grep -q "200"; then
    echo -e "${GREEN}✓ HTTP 200 OK${NC}"
else
    echo -e "${RED}✗ Failed to get HTTP 200${NC}"
    VALIDATION_PASSED=false
fi

echo -n "Testing response content... "
if curl -s -H "Host: www.cluster.local" http://localhost/ | grep -q "Welcome to nginx"; then
    echo -e "${GREEN}✓ nginx welcome page returned${NC}"
else
    echo -e "${RED}✗ Unexpected response${NC}"
    VALIDATION_PASSED=false
fi
echo ""

# Summary
echo "=============================="
if [[ "$VALIDATION_PASSED" == "true" ]]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    echo "Your Consul API Gateway is working correctly."
    echo "Access the application at: http://www.cluster.local"
    exit 0
else
    echo -e "${RED}✗ Some validation checks failed${NC}"
    echo ""
    echo "Troubleshooting tips:"
    echo "1. Check pod logs: kubectl logs -n consul <pod-name>"
    echo "2. Describe failing resources: kubectl describe <resource>"
    echo "3. Check events: kubectl get events -n <namespace>"
    echo "4. Review the README.md Troubleshooting section"
    exit 1
fi
#!/bin/bash
# ==============================================================================
# Cilium Demo — Deploy Script
# ==============================================================================
# This script handles the full lifecycle:
#   1. Install Cilium (if not already installed)
#   2. Build and push Docker images
#   3. Deploy the services
#   4. Apply Cilium network policies
#   5. Run connectivity tests
#
# Usage:
#   ./deploy.sh install-cilium   — Install Cilium + Hubble on the current cluster
#   ./deploy.sh build            — Build Docker images locally
#   ./deploy.sh deploy           — Deploy services to the current cluster
#   ./deploy.sh policies         — Apply Cilium network policies
#   ./deploy.sh test             — Run connectivity tests
#   ./deploy.sh clean            — Remove everything
#   ./deploy.sh all              — Do everything in order
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="cilium-demo"

# Docker Hub username — change this to your own.
DOCKER_USER="${DOCKER_USER:-arpanpathak}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✅]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
err()  { echo -e "${RED}[❌]${NC} $1"; }
info() { echo -e "${CYAN}[ℹ️]${NC} $1"; }

# --------------------------------------------------------------------------
# Install Cilium CLI + Cilium on the cluster
# --------------------------------------------------------------------------
install_cilium() {
    info "Checking if Cilium CLI is installed..."
    if ! command -v cilium &>/dev/null; then
        warn "Cilium CLI not found. Installing..."
        CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
        CLI_ARCH=amd64
        if [ "$(uname -m)" = "arm64" ]; then CLI_ARCH=arm64; fi
        curl -L --fail --remote-name-all \
            "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}"
        shasum -a 256 -c cilium-darwin-${CLI_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC cilium-darwin-${CLI_ARCH}.tar.gz /usr/local/bin
        rm cilium-darwin-${CLI_ARCH}.tar.gz{,.sha256sum}
        log "Cilium CLI installed."
    else
        log "Cilium CLI already installed: $(cilium version --client)"
    fi

    info "Installing Cilium on the current cluster..."
    info "Current context: $(kubectl config current-context)"

    # Install Cilium with Hubble enabled for observability.
    # Vultr's auto-detected cluster name (full UUID) exceeds Cilium's 32-char limit.
    # Override with a short name. If using ClusterMesh later, each cluster needs a unique name.
    CILIUM_CLUSTER_NAME="${CILIUM_CLUSTER_NAME:-vultr-vke}"

    cilium install \
        --set cluster.name="${CILIUM_CLUSTER_NAME}" \
        --set hubble.relay.enabled=true \
        --set hubble.ui.enabled=true \
        --set hubble.enabled=true

    info "Waiting for Cilium to become ready..."
    cilium status --wait

    log "Cilium installed and ready!"
    info "Run 'cilium hubble ui' to open the Hubble dashboard."
}

# --------------------------------------------------------------------------
# Build Docker images
# --------------------------------------------------------------------------
build_images() {
    info "Building catalog-api image..."
    docker build -t "${DOCKER_USER}/cilium-catalog-api:latest" "${SCRIPT_DIR}/catalog-api/"
    log "catalog-api image built."

    info "Building orders-api image..."
    docker build -t "${DOCKER_USER}/cilium-orders-api:latest" "${SCRIPT_DIR}/orders-api/"
    log "orders-api image built."

    info "Pushing images to Docker Hub..."
    docker push "${DOCKER_USER}/cilium-catalog-api:latest"
    docker push "${DOCKER_USER}/cilium-orders-api:latest"
    log "Images pushed."
}

# --------------------------------------------------------------------------
# Deploy services to the cluster
# --------------------------------------------------------------------------
deploy_services() {
    info "Current context: $(kubectl config current-context)"

    info "Creating namespace..."
    kubectl apply -f "${SCRIPT_DIR}/k8s/00-namespace.yaml"

    # Patch the image names to use the user's Docker Hub images.
    info "Deploying catalog-api..."
    sed "s|image: catalog-api:latest|image: ${DOCKER_USER}/cilium-catalog-api:latest|g" \
        "${SCRIPT_DIR}/k8s/01-catalog-deployment.yaml" | kubectl apply -f -

    info "Deploying orders-api..."
    sed "s|image: orders-api:latest|image: ${DOCKER_USER}/cilium-orders-api:latest|g" \
        "${SCRIPT_DIR}/k8s/02-orders-deployment.yaml" | kubectl apply -f -

    info "Deploying intruder pod..."
    kubectl apply -f "${SCRIPT_DIR}/k8s/03-intruder-pod.yaml"

    info "Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app=catalog-api -n "${NAMESPACE}" --timeout=120s
    kubectl wait --for=condition=Ready pod -l app=orders-api -n "${NAMESPACE}" --timeout=120s
    kubectl wait --for=condition=Ready pod -l app=intruder -n "${NAMESPACE}" --timeout=120s

    log "All pods are running!"
    kubectl get pods -n "${NAMESPACE}" -o wide
}

# --------------------------------------------------------------------------
# Apply Cilium network policies
# --------------------------------------------------------------------------
apply_policies() {
    info "Applying Cilium network policies..."

    # Apply in order: specific allow rules first, then default deny.
    kubectl apply -f "${SCRIPT_DIR}/k8s/10-cilium-l3l4-policy.yaml"
    log "L3/L4 policy applied (only orders-api → catalog-api allowed)."

    # Uncomment the next line to enable L7 HTTP filtering as well.
    # kubectl apply -f "${SCRIPT_DIR}/k8s/11-cilium-l7-policy.yaml"
    # log "L7 policy applied (only GET allowed, POST blocked)."

    kubectl apply -f "${SCRIPT_DIR}/k8s/12-cilium-default-deny.yaml"
    log "Default deny policy applied."

    info "Active policies:"
    kubectl get ciliumnetworkpolicies -n "${NAMESPACE}"
}

# --------------------------------------------------------------------------
# Run connectivity tests
# --------------------------------------------------------------------------
run_tests() {
    info "=== Testing connectivity ==="
    echo ""

    # Test 1: orders-api → catalog-api (should SUCCEED)
    info "Test 1: orders-api → catalog-api (GET /items) — should SUCCEED"
    ORDERS_POD=$(kubectl get pod -l app=orders-api -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}')
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" --connect-timeout 10 \
        http://catalog-api.cilium-demo.svc.cluster.local:8080/items \
        && log "✅ orders-api CAN reach catalog-api" \
        || err "orders-api CANNOT reach catalog-api"
    echo ""

    # Test 2: intruder → catalog-api (should FAIL after policies are applied)
    info "Test 2: intruder → catalog-api (GET /items) — should FAIL"
    kubectl exec intruder -n "${NAMESPACE}" -- \
        curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" --connect-timeout 5 \
        http://catalog-api.cilium-demo.svc.cluster.local:8080/items \
        && err "intruder CAN reach catalog-api (policy not working!)" \
        || log "✅ intruder is BLOCKED from catalog-api"
    echo ""

    # Test 3: orders-api → catalog-api POST (should FAIL if L7 policy is applied)
    info "Test 3: orders-api → catalog-api (POST /items) — should FAIL with L7 policy"
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" --connect-timeout 5 \
        -X POST -H "Content-Type: application/json" \
        -d '{"name":"hacked","price":0}' \
        http://catalog-api.cilium-demo.svc.cluster.local:8080/items \
        && warn "POST returned a response (L7 policy may not be applied yet)" \
        || log "✅ POST is BLOCKED by Cilium L7 policy"
    echo ""

    log "Tests complete!"
}

# --------------------------------------------------------------------------
# Enable L7 policy (replaces L3/L4 with the more restrictive L7 version)
# --------------------------------------------------------------------------
enable_l7() {
    info "Enabling L7 HTTP filtering..."
    # Remove the basic L3/L4 policy and apply the L7 version.
    kubectl delete -f "${SCRIPT_DIR}/k8s/10-cilium-l3l4-policy.yaml" --ignore-not-found
    kubectl apply -f "${SCRIPT_DIR}/k8s/11-cilium-l7-policy.yaml"
    log "L7 policy applied! POST requests to catalog-api are now blocked at the kernel level."
    info "Run './deploy.sh test' to verify."
}

# --------------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------------
cleanup() {
    warn "Removing all Cilium demo resources..."
    kubectl delete namespace "${NAMESPACE}" --ignore-not-found
    log "Cleanup complete."
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
case "${1:-help}" in
    install-cilium) install_cilium ;;
    build)          build_images ;;
    deploy)         deploy_services ;;
    policies)       apply_policies ;;
    l7)             enable_l7 ;;
    test)           run_tests ;;
    clean)          cleanup ;;
    all)
        build_images
        deploy_services
        apply_policies
        run_tests
        ;;
    *)
        echo "Usage: $0 {install-cilium|build|deploy|policies|l7|test|clean|all}"
        echo ""
        echo "  install-cilium  — Install Cilium + Hubble on the current cluster"
        echo "  build           — Build and push Docker images"
        echo "  deploy          — Deploy services to the current K8s context"
        echo "  policies        — Apply Cilium L3/L4 network policies"
        echo "  l7              — Upgrade to L7 HTTP-aware policies"
        echo "  test            — Run connectivity tests"
        echo "  clean           — Remove everything"
        echo "  all             — Build, deploy, apply policies, and test"
        ;;
esac

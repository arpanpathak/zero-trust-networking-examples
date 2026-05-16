#!/bin/bash
# ==============================================================================
# Advanced Cilium Exercises — Runner Script
# ==============================================================================
# Usage:
#   ./advanced.sh <exercise-number>    Run a specific exercise
#   ./advanced.sh list                 List all exercises
#   ./advanced.sh reset                Remove all advanced policies
#
# Exercises:
#   1  — Egress Lockdown (block all external traffic)
#   2  — FQDN Egress (allow only specific domains)
#   3  — Header Filtering (API key enforcement at kernel level)
#   4  — Bandwidth Limiting (throttle noisy neighbors)
#   5  — Audit Mode (test policies without breaking things)
#   6  — Path-Based L7 Routing (URL-level firewall)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="cilium-demo"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✅]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
err()  { echo -e "${RED}[❌]${NC} $1"; }
info() { echo -e "${CYAN}[ℹ️]${NC} $1"; }
header() { echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════${NC}"; echo -e "${BOLD}  $1${NC}"; echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════${NC}\n"; }

# Get pod names
get_pods() {
    ORDERS_POD=$(kubectl get pod -l app=orders-api -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    CATALOG_POD=$(kubectl get pod -l app=catalog-api -n "${NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -z "$ORDERS_POD" ]] || [[ -z "$CATALOG_POD" ]]; then
        err "Pods not found. Make sure you've deployed the base demo first: ./deploy.sh deploy"
        exit 1
    fi
}

# --------------------------------------------------------------------------
# Exercise 1: Egress Lockdown
# --------------------------------------------------------------------------
exercise_1() {
    header "Exercise 1: Egress Lockdown — Block All External Traffic"
    get_pods

    info "Step 1: Test egress BEFORE policy (should succeed)..."
    echo ""
    kubectl exec "${CATALOG_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 5 https://httpbin.org/ip \
        && log "External call succeeded (no egress policy yet)" \
        || warn "External call failed (might already be blocked or no internet)"
    echo ""

    info "Step 2: Applying egress lockdown policy..."
    kubectl apply -f "${SCRIPT_DIR}/k8s/advanced/20-egress-lockdown.yaml"
    log "Egress lockdown applied!"
    echo ""

    sleep 3

    info "Step 3: Test egress AFTER policy (should be blocked)..."
    echo ""
    kubectl exec "${CATALOG_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 5 https://httpbin.org/ip \
        && err "External call SUCCEEDED — policy not working!" \
        || log "External call BLOCKED! Egress lockdown working."
    echo ""

    info "Step 4: Verify internal traffic still works..."
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 5 catalog-api:8080/items \
        && log "Internal traffic still works!" \
        || err "Internal traffic broken — check policy"
    echo ""

    info "Watch blocked egress in Hubble:"
    echo "  hubble observe -n cilium-demo --from-label app=catalog-api --verdict DROPPED"
}

# --------------------------------------------------------------------------
# Exercise 2: FQDN Egress
# --------------------------------------------------------------------------
exercise_2() {
    header "Exercise 2: FQDN Egress — Allow Only Specific Domains"
    get_pods

    info "Applying FQDN egress policy..."
    kubectl apply -f "${SCRIPT_DIR}/k8s/advanced/21-fqdn-egress.yaml"
    log "FQDN egress policy applied! Only httpbin.org and ifconfig.me allowed."
    echo ""

    sleep 3

    info "Test 1: Allowed domain (httpbin.org)..."
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 10 https://httpbin.org/ip \
        && log "httpbin.org — ALLOWED ✅" \
        || err "httpbin.org — BLOCKED (should be allowed)"
    echo ""

    info "Test 2: Blocked domain (example.com)..."
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 5 https://example.com \
        && err "example.com — ALLOWED (should be blocked!)" \
        || log "example.com — BLOCKED ✅"
    echo ""

    info "Watch with Hubble:"
    echo "  hubble observe -n cilium-demo --from-label app=orders-api --verdict DROPPED"
}

# --------------------------------------------------------------------------
# Exercise 3: Header Filtering
# --------------------------------------------------------------------------
exercise_3() {
    header "Exercise 3: Header-Based L7 Filtering — API Key Enforcement"
    get_pods

    info "Removing existing L3/L4 policy (will be replaced by header-aware policy)..."
    kubectl delete cnp catalog-api-l3l4-policy -n "${NAMESPACE}" --ignore-not-found
    echo ""

    info "Applying header filtering policy..."
    kubectl apply -f "${SCRIPT_DIR}/k8s/advanced/22-header-filtering.yaml"
    log "Header filtering applied! X-API-Key required."
    echo ""

    sleep 3

    info "Test 1: WITH correct API key header..."
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 10 -w "\nHTTP Status: %{http_code}\n" \
        -H "X-API-Key: trusted-orders-service" \
        catalog-api:8080/items \
        && log "With API key — ALLOWED ✅" \
        || err "With API key — BLOCKED (unexpected)"
    echo ""

    info "Test 2: WITHOUT API key header..."
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 5 -w "\nHTTP Status: %{http_code}\n" \
        catalog-api:8080/items \
        && warn "Without API key — got response (check HTTP status above)" \
        || log "Without API key — BLOCKED ✅"
    echo ""

    info "Watch with Hubble:"
    echo "  hubble observe -n cilium-demo --to-label app=catalog-api --verdict DROPPED"
}

# --------------------------------------------------------------------------
# Exercise 5: Audit Mode
# --------------------------------------------------------------------------
exercise_5() {
    header "Exercise 5: Policy Audit Mode — Dry Run"
    get_pods

    info "Applying policy in AUDIT mode (log, don't enforce)..."
    kubectl apply -f "${SCRIPT_DIR}/k8s/advanced/25-audit-mode.yaml"
    log "Audit policy applied! Traffic will be logged but NOT blocked."
    echo ""

    sleep 3

    info "Test: Intruder accessing catalog (should still work in audit mode)..."
    kubectl exec intruder -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 5 catalog-api:8080/items \
        && log "Intruder access SUCCEEDED (audit mode — not enforcing)" \
        || err "Intruder access BLOCKED (audit mode should not block)"
    echo ""

    info "Watch AUDIT verdicts in Hubble:"
    echo "  hubble observe -n cilium-demo --verdict AUDIT"
    echo ""
    info "When satisfied, enforce the policy:"
    echo "  kubectl annotate cnp catalog-api-audit-policy policy.cilium.io/audit-mode- -n cilium-demo"
}

# --------------------------------------------------------------------------
# Exercise 6: Path-Based Routing
# --------------------------------------------------------------------------
exercise_6() {
    header "Exercise 6: Path-Based L7 Routing — URL-Level Firewall"
    get_pods

    info "Removing existing L3/L4 policy..."
    kubectl delete cnp catalog-api-l3l4-policy -n "${NAMESPACE}" --ignore-not-found
    echo ""

    info "Applying path-based routing policy..."
    kubectl apply -f "${SCRIPT_DIR}/k8s/advanced/26-path-based-routing.yaml"
    log "Path-based routing applied! Only /items and /healthz allowed."
    echo ""

    sleep 3

    info "Test 1: GET /items (allowed path)..."
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 10 -w "\nHTTP Status: %{http_code}\n" \
        catalog-api:8080/items \
        && log "/items — ALLOWED ✅" \
        || err "/items — BLOCKED (unexpected)"
    echo ""

    info "Test 2: GET /admin (blocked path)..."
    kubectl exec "${ORDERS_POD}" -n "${NAMESPACE}" -- \
        curl -s --connect-timeout 5 -w "\nHTTP Status: %{http_code}\n" \
        catalog-api:8080/admin \
        && warn "/admin — got response (check HTTP status — should be 403)" \
        || log "/admin — BLOCKED ✅"
    echo ""

    info "Watch with Hubble:"
    echo "  hubble observe -n cilium-demo --http-path '/admin' --verdict DROPPED"
}

# --------------------------------------------------------------------------
# Reset all advanced policies
# --------------------------------------------------------------------------
reset() {
    warn "Removing all advanced Cilium policies..."
    kubectl delete -f "${SCRIPT_DIR}/k8s/advanced/" --ignore-not-found -n "${NAMESPACE}" 2>/dev/null || true
    kubectl delete pod intruder-throttled -n "${NAMESPACE}" --ignore-not-found
    log "All advanced policies removed."
    echo ""
    info "Re-apply base policies with: ./deploy.sh policies"
}

# --------------------------------------------------------------------------
# List exercises
# --------------------------------------------------------------------------
list_exercises() {
    header "Available Exercises"
    echo "  ${BOLD}1${NC}  Egress Lockdown      — Block all outbound internet traffic from a pod"
    echo "  ${BOLD}2${NC}  FQDN Egress          — Allow only specific external domains (DNS-aware)"
    echo "  ${BOLD}3${NC}  Header Filtering      — Enforce API keys at the kernel level (L7)"
    echo "  ${BOLD}4${NC}  Bandwidth Limiting    — Throttle noisy neighbor pods with eBPF"
    echo "  ${BOLD}5${NC}  Audit Mode            — Test policies without breaking anything"
    echo "  ${BOLD}6${NC}  Path-Based Routing    — URL-level firewall (/items ✅, /admin ❌)"
    echo ""
    echo "  Usage: $0 <number>        Example: $0 1"
    echo "  Reset: $0 reset           Remove all advanced policies"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
case "${1:-list}" in
    1)     exercise_1 ;;
    2)     exercise_2 ;;
    3)     exercise_3 ;;
    4)
        header "Exercise 4: Bandwidth Limiting"
        info "Apply the throttled intruder pod:"
        echo "  kubectl apply -f ${SCRIPT_DIR}/k8s/advanced/23-bandwidth-limit.yaml"
        echo ""
        info "Then test bandwidth:"
        echo "  kubectl exec intruder-throttled -n cilium-demo -- wget -O /dev/null http://catalog-api:8080/items"
        echo ""
        warn "Note: Bandwidth manager must be enabled:"
        echo "  cilium config set enable-bandwidth-manager true"
        ;;
    5)     exercise_5 ;;
    6)     exercise_6 ;;
    list)  list_exercises ;;
    reset) reset ;;
    *)     list_exercises ;;
esac

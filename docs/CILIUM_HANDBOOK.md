# 🛠️ Cilium & Hubble — The Complete Kubectl Handbook

> A comprehensive, copy-paste-ready reference for everything Cilium and Hubble on Kubernetes.

---

## Table of Contents

- [Installation](#-installation)
  - [Cilium CLI](#1-cilium-cli)
  - [Cilium on Kubernetes](#2-cilium-on-kubernetes)
  - [Hubble CLI](#3-hubble-cli)
  - [Hubble Relay & UI](#4-hubble-relay--ui)
- [Cluster Health](#-cluster-health--status)
- [Network Policies](#-network-policies)
- [Endpoints](#-endpoints)
- [Identities](#-identities)
- [Hubble Observability](#-hubble-observability)
- [Agent Debugging](#-cilium-agent-debugging)
- [eBPF Internals](#-ebpf-internals)
- [Encryption](#-encryption-wireguard)
- [ClusterMesh](#-clustermesh)
- [Troubleshooting](#-troubleshooting-playbook)
- [Aliases](#-recommended-aliases)

---

## 📦 Installation

### 1. Cilium CLI

The Cilium CLI is a local tool for installing, managing, and troubleshooting Cilium on your cluster.

**macOS (Homebrew):**
```bash
brew install cilium-cli
```

**macOS (Manual — Apple Silicon):**
```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-arm64.tar.gz{,.sha256sum}"
shasum -a 256 -c cilium-darwin-arm64.tar.gz.sha256sum
sudo tar xzvfC cilium-darwin-arm64.tar.gz /usr/local/bin
rm cilium-darwin-arm64.tar.gz{,.sha256sum}
```

**macOS (Manual — Intel x86_64):**
```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-darwin-amd64.tar.gz{,.sha256sum}"
shasum -a 256 -c cilium-darwin-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-darwin-amd64.tar.gz /usr/local/bin
rm cilium-darwin-amd64.tar.gz{,.sha256sum}
```

**Linux:**
```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz{,.sha256sum}"
sha256sum -c cilium-linux-${ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${ARCH}.tar.gz{,.sha256sum}
```

**Verify:**
```bash
cilium version --client
# Output: cilium-cli: v0.16.x compiled with go1.22.x ...
```

### 2. Cilium on Kubernetes

**Basic install (with Hubble enabled):**
```bash
cilium install \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.enabled=true
```

**With custom cluster name (required if auto-detected name > 32 chars):**
```bash
# Vultr, for example, generates long UUID cluster names
cilium install \
  --set cluster.name=my-cluster \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.enabled=true
```

**With WireGuard encryption:**
```bash
cilium install \
  --set cluster.name=my-cluster \
  --set encryption.enabled=true \
  --set encryption.type=wireguard \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.enabled=true
```

**With Bandwidth Manager:**
```bash
cilium install \
  --set cluster.name=my-cluster \
  --set bandwidthManager.enabled=true \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.enabled=true
```

**Wait for Cilium to be ready:**
```bash
cilium status --wait
```

**Upgrade Cilium:**
```bash
cilium upgrade
```

**Uninstall Cilium:**
```bash
cilium uninstall
```

### 3. Hubble CLI

Hubble CLI is used to observe network flows from the command line.

**macOS (Homebrew):**
```bash
brew install hubble
```

**macOS (Manual):**
```bash
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/arm64/arm64/')
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-darwin-${ARCH}.tar.gz{,.sha256sum}"
shasum -a 256 -c hubble-darwin-${ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-darwin-${ARCH}.tar.gz /usr/local/bin
rm hubble-darwin-${ARCH}.tar.gz{,.sha256sum}
```

**Linux:**
```bash
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${ARCH}.tar.gz{,.sha256sum}"
sha256sum -c hubble-linux-${ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${ARCH}.tar.gz{,.sha256sum}
```

**Verify:**
```bash
hubble version
```

### 4. Hubble Relay & UI

Hubble Relay aggregates flow data from all Cilium agents. The UI provides a visual dashboard.

**Enable on existing cluster (if not enabled during install):**
```bash
cilium hubble enable --ui
```

**Port-forward Hubble Relay (required before using `hubble` CLI):**
```bash
cilium hubble port-forward &
```

**Open Hubble UI in browser:**
```bash
cilium hubble ui
# Opens http://localhost:12000 automatically
```

**Manual port-forward for Hubble UI:**
```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80 &
# Then open http://localhost:12000
```

**Check Hubble status:**
```bash
hubble status
# Output: Healthcheck (via localhost:4245): Ok, ...
```

---

## 🏥 Cluster Health & Status

```bash
# Full Cilium status (agents, operator, relay, encryption)
cilium status

# Wait until Cilium is fully ready (useful in scripts/CI)
cilium status --wait

# Verbose status with all details
cilium status --verbose

# Version info (client + cluster)
cilium version

# View current Cilium configuration
cilium config view

# Run the built-in connectivity test suite
# (creates a test namespace, runs 40+ connectivity checks, then cleans up)
cilium connectivity test
```

---

## 📜 Network Policies

### Listing Policies

```bash
# List CiliumNetworkPolicies in a namespace
kubectl get ciliumnetworkpolicies -n cilium-demo
kubectl get cnp -n cilium-demo                        # shorthand

# List with additional info
kubectl get cnp -n cilium-demo -o wide

# List cluster-wide policies (not namespace-scoped)
kubectl get ciliumclusterwidenetworkpolicies
kubectl get ccnp                                       # shorthand

# List ALL Cilium policies across ALL namespaces
kubectl get cnp --all-namespaces
kubectl get cnp -A                                     # shorthand
```

### Inspecting Policies

```bash
# Detailed view of a specific policy
kubectl describe cnp catalog-api-l3l4-policy -n cilium-demo

# Export policy as YAML (for backup or review)
kubectl get cnp catalog-api-l3l4-policy -n cilium-demo -o yaml

# Export as JSON (for scripting / jq)
kubectl get cnp catalog-api-l3l4-policy -n cilium-demo -o json

# Check if a policy is valid (look for "Valid: True")
kubectl get cnp -n cilium-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[0].type}{"\t"}{.status.conditions[0].status}{"\n"}{end}'
```

### Managing Policies

```bash
# Apply a policy
kubectl apply -f k8s/10-cilium-l3l4-policy.yaml

# Delete a specific policy
kubectl delete cnp catalog-api-l3l4-policy -n cilium-demo

# Delete ALL policies in a namespace
kubectl delete cnp --all -n cilium-demo

# Watch for policy changes in real-time
kubectl get cnp -n cilium-demo -w
```

---

## 🔌 Endpoints

Every pod managed by Cilium has a CiliumEndpoint (CEP). This is where you see per-pod identity, IP, and policy enforcement status.

```bash
# List all endpoints in a namespace
kubectl get ciliumendpoints -n cilium-demo
kubectl get cep -n cilium-demo                         # shorthand

# Detailed view (shows identity, IP, policy status)
kubectl get cep -n cilium-demo -o wide

# Describe a specific endpoint
kubectl describe cep <endpoint-name> -n cilium-demo

# Get endpoint identities as a quick table
kubectl get cep -n cilium-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}ID:{.status.identity.id}{"\t"}{.status.networking.addressing[0].ipv4}{"\n"}{end}'
```

### Deep Endpoint Inspection (from Cilium Agent)

```bash
# Get a Cilium agent pod name
CILIUM_POD=$(kubectl get pod -n kube-system -l k8s-app=cilium \
  -o jsonpath='{.items[0].metadata.name}')

# List all endpoints with status
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg endpoint list

# Get detailed info for a specific endpoint ID
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg endpoint get <ID>

# Show endpoint health
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg endpoint health <ID>
```

---

## 🆔 Identities

Cilium assigns numeric identities to pods based on their labels. Policies operate on identities, not IPs.

```bash
# List all identities in the cluster
kubectl get ciliumidentities
kubectl get ciliumid                                   # shorthand

# List with label details
kubectl get ciliumidentities -o wide

# Find the identity for a specific set of labels
kubectl get ciliumid -o json | jq '.items[] | select(.security_labels."k8s:app" == "catalog-api") | .metadata.name'

# From inside the Cilium agent
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg identity list

# Lookup a specific identity by ID
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg identity get <identity-id>
```

---

## 🔭 Hubble Observability

Hubble is the real-time network flow observer built on eBPF. Think "Wireshark for Kubernetes."

### Setup (Run Once Per Session)

```bash
# Port-forward Hubble Relay (required before using CLI)
cilium hubble port-forward &
```

### Watching Flows

```bash
# All flows in a namespace
hubble observe -n cilium-demo

# Follow mode (live stream, like tail -f)
hubble observe -n cilium-demo -f

# Last N flows
hubble observe -n cilium-demo --last 50
hubble observe -n cilium-demo --last 200
```

### Filtering by Verdict

```bash
# Only DROPPED traffic (blocked by policy) — THE money command
hubble observe -n cilium-demo --verdict DROPPED

# Only FORWARDED traffic (allowed by policy)
hubble observe -n cilium-demo --verdict FORWARDED

# Only AUDIT traffic (policy in audit mode, would be dropped)
hubble observe -n cilium-demo --verdict AUDIT

# Combine: dropped traffic, live stream
hubble observe -n cilium-demo --verdict DROPPED -f
```

### Filtering by Pod

```bash
# Traffic FROM a specific pod
hubble observe --from-pod cilium-demo/intruder

# Traffic TO a specific pod
hubble observe --to-pod cilium-demo/catalog-api-7c8f9d6b4-x2k9p

# Between two specific pods
hubble observe \
  --from-pod cilium-demo/orders-api-5d8f7c6b4-abc12 \
  --to-pod cilium-demo/catalog-api-7c8f9d6b4-x2k9p
```

### Filtering by Label

```bash
# From pods with a specific label
hubble observe -n cilium-demo --from-label app=intruder

# To pods with a specific label
hubble observe -n cilium-demo --to-label app=catalog-api

# Combine label filters
hubble observe -n cilium-demo \
  --from-label app=orders-api \
  --to-label app=catalog-api
```

### Filtering by Protocol & Port

```bash
# Only HTTP traffic
hubble observe -n cilium-demo --protocol http

# Only DNS traffic (great for debugging resolution issues)
hubble observe -n cilium-demo --protocol dns

# Only TCP traffic on a specific port
hubble observe -n cilium-demo --port 8080

# Only ICMP (ping)
hubble observe -n cilium-demo --protocol icmp
```

### Filtering by HTTP (L7)

```bash
# By HTTP method
hubble observe -n cilium-demo --http-method GET
hubble observe -n cilium-demo --http-method POST

# By URL path
hubble observe -n cilium-demo --http-path "/items"
hubble observe -n cilium-demo --http-path "/admin"

# By HTTP status code
hubble observe -n cilium-demo --http-status 200
hubble observe -n cilium-demo --http-status 403
hubble observe -n cilium-demo --http-status 500

# Combine: blocked POST requests to catalog-api
hubble observe -n cilium-demo \
  --to-label app=catalog-api \
  --http-method POST \
  --verdict DROPPED \
  -f
```

### Output Formats

```bash
# Default compact format
hubble observe -n cilium-demo

# JSON (pipe to jq for processing)
hubble observe -n cilium-demo -o json

# Extract specific fields with jq
hubble observe -n cilium-demo -o json | \
  jq '{src: .flow.source.labels, dst: .flow.destination.labels, verdict: .flow.verdict}'

# Table format (wider, more columns)
hubble observe -n cilium-demo -o table

# Dict format (verbose, all fields)
hubble observe -n cilium-demo -o dict
```

### Hubble Metrics

```bash
# Check Hubble flow metrics
hubble observe -n cilium-demo -o json | jq '.flow.Type'

# Count flows per verdict
hubble observe -n cilium-demo --last 1000 -o json | \
  jq -r '.flow.verdict' | sort | uniq -c | sort -rn
```

---

## 🔍 Cilium Agent Debugging

### Logs

```bash
# Find Cilium agent pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Tail Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium -f --tail=100

# Cilium operator logs
kubectl logs -n kube-system -l name=cilium-operator -f --tail=100

# Hubble relay logs
kubectl logs -n kube-system -l k8s-app=hubble-relay -f --tail=100

# Filter for specific topics
kubectl logs -n kube-system -l k8s-app=cilium -f | grep -i policy
kubectl logs -n kube-system -l k8s-app=cilium -f | grep -i endpoint
kubectl logs -n kube-system -l k8s-app=cilium -f | grep -i "level=error"
```

### Policy Debugging

```bash
CILIUM_POD=$(kubectl get pod -n kube-system -l k8s-app=cilium \
  -o jsonpath='{.items[0].metadata.name}')

# Show all resolved policies
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg policy get

# Trace a connection (dry-run policy evaluation)
# "Would traffic from pod A to pod B on port 8080 be allowed?"
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg policy trace \
  --src-k8s-pod cilium-demo:orders-api-xxxxx \
  --dst-k8s-pod cilium-demo:catalog-api-yyyyy \
  --dport 8080

# Selectors: which endpoints match a given policy
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg policy selectors
```

### Service & Load Balancing

```bash
# List all services Cilium is load-balancing
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg service list

# Show node information
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg node list

# Show managed IP addresses
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg ip list
```

---

## 🐝 eBPF Internals

Deep inspection of the eBPF data structures Cilium uses in the kernel.

```bash
CILIUM_POD=$(kubectl get pod -n kube-system -l k8s-app=cilium \
  -o jsonpath='{.items[0].metadata.name}')

# Connection Tracking table (see all active connections)
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg bpf ct list global | head -30

# NAT table (Network Address Translation entries)
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg bpf nat list

# Policy verdict map (which identity pairs are allowed)
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg bpf policy get --all

# Tunnel map (VXLAN/Geneve tunnel endpoints)
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg bpf tunnel list

# Endpoint map
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg bpf endpoint list

# LB maps (load balancer backend state)
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg bpf lb list

# Map sizes and memory usage
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg map list
```

---

## 🔐 Encryption (WireGuard)

```bash
# Check encryption status
cilium status | grep Encryption

# Detailed encryption status from agent
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg encrypt status

# Enable WireGuard on existing cluster
cilium config set enable-wireguard true
cilium config set encryption-type wireguard

# Verify WireGuard interfaces
kubectl exec $CILIUM_POD -n kube-system -- ip link show cilium_wg0

# Check WireGuard peers
kubectl exec $CILIUM_POD -n kube-system -- wg show
```

---

## 🌐 ClusterMesh

Connect multiple Kubernetes clusters for cross-cluster service discovery.

```bash
# Enable ClusterMesh on the current cluster
cilium clustermesh enable

# Check ClusterMesh status
cilium clustermesh status

# Connect two clusters (run from cluster A)
cilium clustermesh connect --destination-context <cluster-B-context>

# Disconnect clusters
cilium clustermesh disconnect --destination-context <cluster-B-context>

# Disable ClusterMesh
cilium clustermesh disable
```

---

## 🔧 Troubleshooting Playbook

### "My pod can't reach another pod"

```bash
# Step 1: Check if policies are blocking it
hubble observe -n <namespace> --from-label app=<source> --verdict DROPPED -f

# Step 2: Check endpoint status
kubectl get cep -n <namespace> -o wide

# Step 3: Policy trace (dry-run)
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg policy trace \
  --src-k8s-pod <namespace>:<source-pod> \
  --dst-k8s-pod <namespace>:<dest-pod> \
  --dport <port>

# Step 4: Check DNS resolution
hubble observe -n <namespace> --protocol dns --from-label app=<source>

# Step 5: Check if dest pod is healthy
kubectl get pods -n <namespace> -l app=<dest> -o wide
```

### "Health probes are failing (pods keep restarting)"

```bash
# Check if kubelet traffic is being dropped
hubble observe -n <namespace> --verdict DROPPED | grep health

# Verify 'host' entity is in your policy
kubectl get cnp -n <namespace> -o yaml | grep -A5 fromEntities
# Must include: host, health, kube-apiserver
```

### "DNS is not working"

```bash
# Watch DNS flows
hubble observe -n <namespace> --protocol dns -f

# Check if DNS egress is allowed
hubble observe -n <namespace> --port 53 --verdict DROPPED

# Verify kube-dns is reachable
kubectl exec <pod> -n <namespace> -- nslookup kubernetes.default
```

### "L7 policy isn't blocking HTTP methods"

```bash
# Verify L7 policy is active
kubectl describe cnp <policy-name> -n <namespace>
# Look for "Rules: Http:" section

# Check if Cilium's L7 proxy is running
kubectl exec $CILIUM_POD -n kube-system -- cilium-dbg status | grep Proxy

# Watch HTTP-level flows
hubble observe -n <namespace> --protocol http --http-method POST -f
```

### "Egress to external services is not blocked"

```bash
# Check egress policies exist
kubectl get cnp -n <namespace> -o yaml | grep -A20 egress

# Watch egress flows
hubble observe -n <namespace> --to-label reserved:world --verdict DROPPED

# Verify DNS is not leaking (should only go to kube-dns)
hubble observe -n <namespace> --port 53 -f
```

### "Cilium agents are crashing"

```bash
# Check agent pod status
kubectl get pods -n kube-system -l k8s-app=cilium

# Check for OOM kills
kubectl describe pod -n kube-system -l k8s-app=cilium | grep -A5 "Last State"

# Check resource usage
kubectl top pods -n kube-system -l k8s-app=cilium

# Check events
kubectl events -n kube-system --for=pod/<cilium-pod-name>
```

---

## 🧩 Cilium CRD Quick Reference

```bash
# All Cilium Custom Resource Definitions
kubectl api-resources | grep cilium

# Common CRDs and their shorthands:
# CiliumNetworkPolicy          → cnp
# CiliumClusterwideNetworkPolicy → ccnp
# CiliumEndpoint               → cep
# CiliumIdentity               → ciliumid
# CiliumNode                   → cn
# CiliumExternalWorkload       → cew

# Get everything Cilium in one command
kubectl get cnp,cep,ciliumid -n cilium-demo

# Get all Cilium resources across all namespaces
kubectl get cnp -A
```

---

## ⚡ Recommended Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# --- Cilium ---
alias cs='cilium status'
alias csw='cilium status --wait'
alias cv='cilium version'
alias cc='cilium config view'
alias ct='cilium connectivity test'

# --- kubectl + Cilium ---
alias kcnp='kubectl get cnp'
alias kcep='kubectl get cep'
alias kcid='kubectl get ciliumid'
alias kdcnp='kubectl describe cnp'

# --- Hubble ---
alias ho='hubble observe'
alias hof='hubble observe -f'
alias hod='hubble observe --verdict DROPPED'
alias hodf='hubble observe --verdict DROPPED -f'
alias hoh='hubble observe --protocol http'
alias hodns='hubble observe --protocol dns'
alias hui='cilium hubble ui'
alias hpf='cilium hubble port-forward &'

# --- Cilium Agent ---
alias cpod='kubectl get pod -n kube-system -l k8s-app=cilium -o jsonpath="{.items[0].metadata.name}"'
alias clogs='kubectl logs -n kube-system -l k8s-app=cilium -f --tail=100'
alias cologs='kubectl logs -n kube-system -l name=cilium-operator -f --tail=100'
```

**Usage after sourcing:**
```bash
source ~/.zshrc

# Quick dropped traffic watch
hod -n cilium-demo

# Quick policy list
kcnp -n cilium-demo

# Quick Cilium status
cs
```

---

<p align="center">
  <sub>Built with ☕ and eBPF by <a href="https://github.com/arpanpathak">@arpanpathak</a></sub>
</p>

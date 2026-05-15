<p align="center">
  <img src="https://raw.githubusercontent.com/cilium/cilium/main/Documentation/images/logo-dark.png" alt="Cilium Logo" width="180">
</p>

<h1 align="center">🔒 Zero Trust Networking Examples</h1>

<p align="center">
  <strong>Production-ready eBPF network security on Kubernetes — from L3/L4 micro-segmentation to L7 HTTP filtering.</strong>
</p>

<p align="center">
  <a href="https://cilium.io"><img src="https://img.shields.io/badge/Cilium-eBPF-blueviolet?style=flat-square&logo=cilium" alt="Cilium"></a>
  <a href="https://kubernetes.io"><img src="https://img.shields.io/badge/Kubernetes-Networking-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="Kubernetes"></a>
  <a href="https://go.dev"><img src="https://img.shields.io/badge/Go-Microservices-00ADD8?style=flat-square&logo=go&logoColor=white" alt="Go"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-policy-examples">Policy Examples</a> •
  <a href="#-demo-walkthrough">Demo Walkthrough</a> •
  <a href="#-observability-with-hubble">Hubble</a> •
  <a href="#-infrastructure">Infrastructure</a>
</p>

---

## 📖 Overview

This repository contains **hands-on examples** of Zero Trust networking on Kubernetes using [Cilium's eBPF](https://cilium.io/) technology. Instead of relying on traditional iptables-based firewalls, Cilium enforces network policies **directly in the Linux kernel** using eBPF programs — providing:

- **L3/L4 Micro-Segmentation** — Control which pods can talk to which pods on which ports
- **L7 HTTP-Aware Filtering** — Allow `GET` but block `POST` at the kernel level (impossible with iptables)
- **Default Deny (Zero Trust)** — Block everything by default, explicitly allow only what's needed
- **Real-Time Flow Visibility** — Watch allowed and denied traffic via Hubble (like Wireshark for K8s)

> **Why eBPF over iptables?** Traditional Kubernetes NetworkPolicies use iptables, which operates at L3/L4 only. Cilium's eBPF operates at L3–L7, can inspect HTTP methods/paths, and scales without the O(n) iptables rule-chain penalty.

---

## 🏗 Architecture

```
┌───────────────────────────────────────────────────────────┐
│                  Namespace: cilium-demo                    │
│                                                           │
│  ┌───────────────┐    GET /items     ┌─────────────────┐  │
│  │  orders-api   │ ──── ✅ ───────▶ │   catalog-api   │  │
│  │  (frontend)   │    POST /items    │   (backend)     │  │
│  │               │ ──── ❌ ───────▶ │                 │  │
│  └───────────────┘                   └─────────────────┘  │
│                                             ▲             │
│  ┌───────────────┐    ANY request    ❌     │             │
│  │   intruder    │ ──── BLOCKED ───────────┘             │
│  │  (attacker)   │                                       │
│  └───────────────┘                                       │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Cilium eBPF (Linux Kernel)              │  │
│  │  • L3/L4: Pod-level micro-segmentation              │  │
│  │  • L7:    HTTP method + path filtering              │  │
│  │  • Hubble: Real-time flow observability             │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
```

### Components

| Service | Role | Language | Description |
|---------|------|----------|-------------|
| **catalog-api** | Backend | Go | Serves product catalog (`GET /items`, `POST /items`). The "protected" service. |
| **orders-api** | Frontend | Go | Calls catalog-api internally. The "authorized" client. |
| **intruder** | Attacker | alpine/curl | Simulates unauthorized access. Used to verify policies block bad actors. |

---

## 📋 Policy Examples

### 1. L3/L4 Micro-Segmentation — `k8s/10-cilium-l3l4-policy.yaml`

> *"Only orders-api can talk to catalog-api on port 8080. Everything else is denied."*

```yaml
spec:
  endpointSelector:
    matchLabels:
      app: catalog-api
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: orders-api
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

### 2. L7 HTTP Filtering — `k8s/11-cilium-l7-policy.yaml`

> *"Even orders-api can only `GET` — `POST` is blocked at the kernel level."*

```yaml
rules:
  http:
    - method: GET
      path: "/items"
    - method: GET
      path: "/healthz"
```

This is **impossible with traditional Kubernetes NetworkPolicies** — they can't inspect HTTP methods. Cilium's eBPF programs parse every packet in the kernel, matching against L7 rules with near-zero overhead.

### 3. Default Deny (Zero Trust) — `k8s/12-cilium-default-deny.yaml`

> *"Block ALL traffic by default. Only explicitly allowed flows get through."*

```yaml
spec:
  endpointSelector: {}    # Matches ALL pods in the namespace
  ingress:
    - fromEntities:
        - host            # Kubelet health probes
        - health          # Cilium health checks
        - kube-apiserver  # API server communication
```

---

## 🚀 Quick Start

### Prerequisites

- A running Kubernetes cluster ([deploy one here →](https://github.com/arpanpathak/cloudnative-books-app))
- Docker (for building images)
- `kubectl` configured and pointing to your cluster

### Step 1: Install Cilium

```bash
./deploy.sh install-cilium
```

This installs Cilium with Hubble (observability) enabled. If your managed K8s provider already has Cilium as the CNI, skip this step.

### Step 2: Build & Push Images

```bash
export DOCKER_USER="your-dockerhub-username"
./deploy.sh build
```

### Step 3: Deploy Services

```bash
./deploy.sh deploy
```

### Step 4: Verify Open Access (Before Policies)

```bash
# The intruder CAN access catalog-api — this is the problem!
kubectl exec intruder -n cilium-demo -- curl -s catalog-api:8080/items
# ✅ Returns items — BAD! No security at all.
```

### Step 5: Apply Cilium Policies

```bash
./deploy.sh policies
```

### Step 6: Run Connectivity Tests

```bash
./deploy.sh test
```

**Expected results:**

```
✅ orders-api → catalog-api (GET /items)  — ALLOWED
❌ intruder   → catalog-api (GET /items)  — BLOCKED
```

### Step 7: Enable L7 HTTP Filtering (Advanced)

```bash
./deploy.sh l7
./deploy.sh test
```

**Now even the authorized client is restricted:**

```
✅ orders-api → catalog-api (GET  /items)  — ALLOWED
❌ orders-api → catalog-api (POST /items)  — BLOCKED by eBPF
❌ intruder   → catalog-api (GET  /items)  — BLOCKED
```

### Cleanup

```bash
./deploy.sh clean
```

---

## 🔭 Observability with Hubble

Cilium ships with [Hubble](https://docs.cilium.io/en/stable/gettingstarted/hubble/), a real-time network flow observability tool built on eBPF.

```bash
# Launch the Hubble UI (opens in browser)
cilium hubble ui

# Or watch flows from the CLI
hubble observe -n cilium-demo

# Watch ONLY denied/dropped traffic
hubble observe -n cilium-demo --verdict DROPPED
```

Hubble shows you **exactly** which packets are being allowed or denied, with full metadata: source pod, destination pod, L4 port, L7 HTTP method/path, and the policy that made the decision.

---

## 🏢 Infrastructure

**Need a Kubernetes cluster to run this on?**

👉 **[cloudnative-books-app](https://github.com/arpanpathak/cloudnative-books-app)** — Terraform-based multi-cloud Kubernetes infrastructure across **Vultr**, **Linode**, and **Azure**. Deploy a production-grade cluster in minutes with:

```bash
git clone https://github.com/arpanpathak/cloudnative-books-app.git
cd cloudnative-books-app/infra/vultr
terraform init && terraform apply
```

The infrastructure repo handles VKE/LKE/AKS cluster provisioning, kubeconfig merging, and is designed to work seamlessly with this Zero Trust demo.

---

## 📁 Project Structure

```
zero-trust-networking-examples/
├── catalog-api/                         # Protected backend microservice (Go)
│   ├── main.go                          # HTTP server: GET/POST /items, /healthz
│   ├── internal/
│   │   ├── handlers/catalog.go          # HTTP handlers
│   │   ├── models/item.go               # Domain models
│   │   └── store/catalog.go             # In-memory data store
│   ├── Dockerfile                       # Multi-stage build
│   └── go.mod
├── orders-api/                          # Authorized frontend microservice (Go)
│   ├── main.go                          # Proxies requests to catalog-api
│   ├── internal/
│   │   ├── client/catalog.go            # HTTP client for catalog-api
│   │   ├── handlers/order.go            # HTTP handlers
│   │   ├── models/order.go              # Domain models
│   │   └── store/order.go               # In-memory data store
│   ├── Dockerfile                       # Multi-stage build
│   └── go.mod
├── k8s/
│   ├── 00-namespace.yaml                # Isolated namespace
│   ├── 01-catalog-deployment.yaml       # Catalog pods + ClusterIP service
│   ├── 02-orders-deployment.yaml        # Orders pods + ClusterIP service
│   ├── 03-intruder-pod.yaml             # Simulated attacker pod
│   ├── 10-cilium-l3l4-policy.yaml       # L3/L4: Only orders → catalog
│   ├── 11-cilium-l7-policy.yaml         # L7: Only GET, block POST
│   └── 12-cilium-default-deny.yaml      # Zero Trust default deny
├── deploy.sh                            # One-stop deployment automation
└── README.md
```

---

## 🧠 Key Concepts

| Concept | Traditional (iptables) | Cilium (eBPF) |
|---------|----------------------|---------------|
| **Layer** | L3/L4 only | L3 through L7 |
| **HTTP Filtering** | ❌ Impossible | ✅ Method + Path + Headers |
| **Performance** | O(n) rule chains | O(1) eBPF maps |
| **Observability** | tcpdump / packet captures | Hubble (real-time flows) |
| **Identity** | IP-based | Label-based (Kubernetes-native) |
| **Scalability** | Degrades with rule count | Constant regardless of rules |

---

## 📚 Further Reading

- [Cilium Documentation](https://docs.cilium.io/) — Official docs
- [eBPF.io](https://ebpf.io/) — Learn about eBPF technology
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) — Standard K8s policies (L3/L4 only)
- [Hubble Observability](https://docs.cilium.io/en/stable/gettingstarted/hubble/) — Flow visibility setup

---

## 🤝 Contributing

Contributions are welcome! If you'd like to add more examples (e.g., egress policies, DNS-aware policies, ClusterMesh cross-cluster rules), feel free to open a PR.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/egress-policies`)
3. Commit your changes (`git commit -m 'Add egress policy examples'`)
4. Push to the branch (`git push origin feature/egress-policies`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <sub>Built with ☕ and eBPF by <a href="https://github.com/arpanpathak">@arpanpathak</a></sub>
</p>

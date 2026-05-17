# 🏛️ Sovereign Cloud: Data Residency Enforcement with Cilium eBPF

> **"Nothing leaves Seattle. Everything stays within Seattle."**

A production-grade demonstration of **data sovereignty enforcement** on Kubernetes using Cilium eBPF network policies. This example shows how to technically enforce data residency regulations — ensuring that data never leaves a specific geographic boundary, even at the network packet level.

---

## 📖 Why Data Sovereignty Matters

In an era of escalating **geopolitical tensions**, governments worldwide are demanding that citizen data stays within their borders. This isn't just compliance theater — it's a **technical enforcement problem**:

- A single misconfigured DNS record could route EU citizen data through a US server, violating GDPR.
- A developer adding a third-party analytics SDK could exfiltrate Chinese user data, violating PIPL.
- A cloud provider's load balancer could route traffic through a datacenter in a non-approved country.

**The only way to guarantee data sovereignty is at the network level.** Application-level controls (middleware, config flags) are necessary but insufficient — they can be bypassed. Cilium's eBPF policies operate **in the Linux kernel**, below the application layer, making them impossible to circumvent from userspace.

---

## 🌍 Global Data Sovereignty Laws — A Technical Reference

### Tier 1: Strict Data Localization (Data MUST stay in-country)

| Country | Law | Key Requirement | Penalty |
|---------|-----|-----------------|---------|
| 🇨🇳 **China** | PIPL + Cybersecurity Law (CSL) | Personal data must be stored in China. Cross-border transfers require CAC (Cyberspace Administration of China) security review. Critical data cannot leave. | Up to ¥50M (~$7M) or 5% of annual revenue |
| 🇷🇺 **Russia** | Federal Law 242-FZ | Personal data of Russian citizens must be stored on servers physically located in Russia. | Blocking of services + fines |
| 🇻🇳 **Vietnam** | Decree 13/2023/NĐ-CP | Personal data must be stored in Vietnam. Cross-border transfer requires impact assessment + government registration. | Up to 5% of revenue in Vietnam |
| 🇮🇩 **Indonesia** | PDP Law (UU PDP 2022) | Personal data must be accessible from within Indonesia. Government data must be stored domestically. | Up to 2% of annual revenue |
| 🇸🇦 **Saudi Arabia** | PDPL (2023) | Certain categories of personal data cannot leave the Kingdom without SDAIA approval. | Up to SAR 5M (~$1.3M) |

### Tier 2: Conditional Cross-Border Transfer (Transfer allowed with safeguards)

| Country | Law | Key Requirement | Penalty |
|---------|-----|-----------------|---------|
| 🇪🇺 **EU/EEA** | GDPR (2018) | Cross-border transfer only to "adequate" countries (per EU Commission) or with Standard Contractual Clauses (SCCs). Schrems II invalidated EU-US Privacy Shield. | Up to €20M or 4% of global revenue |
| 🇧🇷 **Brazil** | LGPD (2020) | Transfer to countries with "adequate" protection or with specific safeguards (SCCs, BCRs). | Up to 2% of revenue, capped at R$50M (~$10M) |
| 🇮🇳 **India** | DPDPA (2023) | Government can restrict transfer to specific countries via notification. Currently no blanket localization, but blacklist approach. | Up to ₹250 Cr (~$30M) |
| 🇰🇷 **South Korea** | PIPA (2023 amended) | Cross-border transfer requires consent OR adequate protection. Mandatory notification to data subjects. | Up to 3% of related revenue |
| 🇯🇵 **Japan** | APPI (2022 amended) | Cross-border transfer requires consent, adequacy (EU mutual), or equivalent safeguards. | Up to ¥100M (~$670K) + criminal penalties |
| 🇿🇦 **South Africa** | POPIA (2021) | Transfer only to countries with adequate protection, with consent, or under contract. | Up to ZAR 10M (~$550K) or imprisonment |
| 🇦🇺 **Australia** | Privacy Act 1988 + APPs | Transferring entity remains liable for overseas recipient's handling. Must ensure equivalent protection. | Up to AUD $50M or 30% of turnover |
| 🇹🇷 **Turkey** | KVKK (2016) | Transfer to countries with adequate protection (per KVKK Board) or with binding undertakings. | Up to TRY 10M (~$300K) |
| 🇦🇪 **UAE** | Federal Decree-Law No. 45/2021 | Cross-border transfer allowed with adequate safeguards or consent. Free zones (DIFC, ADGM) have separate rules. | Up to AED 5M (~$1.36M) |

### Tier 3: US State-Level Privacy Laws

| State | Law | Year | Key Focus |
|-------|-----|------|-----------|
| 🇺🇸 **California** | CCPA / CPRA | 2020/2023 | Consumer rights (access, delete, opt-out). No strict localization but requires "reasonable security." |
| 🇺🇸 **Virginia** | VCDPA | 2023 | Consumer data rights. Data protection assessments required. |
| 🇺🇸 **Colorado** | CPA | 2023 | Universal opt-out mechanism. Data minimization. |
| 🇺🇸 **Connecticut** | CTDPA | 2023 | Similar to VCDPA. Consent for sensitive data. |
| 🇺🇸 **Utah** | UCPA | 2023 | Business-friendly. Narrower scope. |
| 🇺🇸 **Texas** | TDPSA | 2024 | No revenue threshold. Broad applicability. |

### Tier 4: Sector-Specific (US Federal)

| Regulation | Sector | Data Residency Requirement |
|------------|--------|---------------------------|
| **HIPAA** | Healthcare | No explicit localization, but "reasonable safeguards" + BAAs for third parties |
| **ITAR** | Defense/Munitions | Technical data MUST NOT leave US or approved countries |
| **FISMA/FedRAMP** | Federal Government | Data must reside in FedRAMP-authorized datacenters (US soil) |
| **SOX** | Financial (public companies) | Audit data must be accessible; practical US residency requirement |
| **GLBA** | Financial Services | Safeguards rule; practical domestic processing requirement |

---

## 🏗️ Architecture: What We're Building

```
┌──────────────────────────────────────────────────────────────────┐
│                    SOVEREIGN ZONE: SEATTLE (SEA)                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Namespace: sovereign-seattle                 │    │
│  │              Labels:                                      │    │
│  │                data-residency: us-west-seattle            │    │
│  │                compliance: ccpa,hipaa                      │    │
│  │                classification: confidential               │    │
│  │                                                           │    │
│  │  ┌─────────────┐         ┌──────────────┐                │    │
│  │  │ catalog-api  │ ◄────── │  orders-api  │                │    │
│  │  │ (PII store)  │         │  (frontend)  │                │    │
│  │  │ SEA-pinned   │         │  SEA-pinned  │                │    │
│  │  └─────────────┘         └──────────────┘                │    │
│  │         │                        │                        │    │
│  │         │    ┌───────────────┐   │                        │    │
│  │         └───►│ Cilium eBPF   │◄──┘                        │    │
│  │              │               │                             │    │
│  │              │ ENFORCES:     │                             │    │
│  │              │ ✅ SEA → SEA  │                             │    │
│  │              │ ❌ SEA → LAX  │                             │    │
│  │              │ ❌ SEA → EU   │                             │    │
│  │              │ ❌ SEA → ANY  │                             │    │
│  │              └───────────────┘                             │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │  WireGuard Encryption (Node-to-Node)                      │    │
│  │  All data encrypted in transit — no plaintext on the wire │    │
│  └──────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
                              ▲
                              │ ❌ BLOCKED
                              │
              ┌───────────────┴───────────────┐
              │   External / Other Regions     │
              │   • EU datacenters             │
              │   • Analytics services         │
              │   • Third-party APIs           │
              │   • Non-sovereign clusters     │
              └───────────────────────────────┘
```

---

## 🔧 Technical Enforcement Layers

Data sovereignty requires **defense in depth**. A single mechanism is never enough.

### Layer 1: Compute Pinning (Kubernetes Node Affinity)

> **"Data can only be processed on machines in the approved region."**

```yaml
# Pin pods to nodes labeled with the Seattle region
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: topology.kubernetes.io/region
              operator: In
              values: ["us-sea-1"]
```

Kubernetes will **refuse to schedule** the pod on any node not labeled as being in Seattle. If all Seattle nodes go down, the pod stays in `Pending` — it will NOT fail over to a non-sovereign region.

### Layer 2: Network Egress Lockdown (Cilium eBPF)

> **"Even if the code tries to send data out, the kernel blocks it."**

```yaml
# Block ALL external egress — data cannot leave the cluster
egress:
  - toEntities:
      - host
      - kube-apiserver
  - toEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": sovereign-seattle
```

This is the **hard boundary**. Even if a developer introduces a bug that calls an external API, or a compromised dependency tries to exfiltrate data, the eBPF program in the kernel will drop the packet before it leaves the node.

### Layer 3: Encryption in Transit (WireGuard)

> **"Even if someone taps the wire between nodes, they see nothing."**

Cilium's WireGuard integration encrypts all pod-to-pod traffic at the node level. No sidecars, no certificate management, no application changes.

### Layer 4: Namespace Isolation (Cilium Default Deny)

> **"Sovereign workloads cannot communicate with non-sovereign workloads."**

Pods in the `sovereign-seattle` namespace can only talk to other pods in the same namespace. Cross-namespace traffic is denied by default.

---

## 🚀 Quick Start

### Prerequisites

- A Kubernetes cluster with Cilium installed ([deploy one here](https://github.com/arpanpathak/cloudnative-books-app))
- `kubectl` configured to point to your cluster

### Step 1: Label Your Nodes

```bash
# Label your Seattle nodes (adjust node names for your cluster)
kubectl label nodes <node-name> \
  topology.kubernetes.io/region=us-sea-1 \
  data-sovereignty=us \
  --overwrite
```

### Step 2: Create the Sovereign Namespace

```bash
kubectl apply -f k8s/sovereign-cloud/30-sovereign-namespace.yaml
```

### Step 3: Deploy Workloads with Node Pinning

```bash
kubectl apply -f k8s/sovereign-cloud/31-sovereign-workloads.yaml
```

### Step 4: Apply Sovereignty Policies

```bash
# Egress lockdown — nothing leaves the cluster
kubectl apply -f k8s/sovereign-cloud/32-sovereign-egress.yaml

# Cross-namespace isolation — sovereign pods can't talk to non-sovereign pods
kubectl apply -f k8s/sovereign-cloud/33-namespace-isolation.yaml

# Default deny — zero trust baseline for the sovereign namespace
kubectl apply -f k8s/sovereign-cloud/34-sovereign-default-deny.yaml
```

### Step 5: Test Enforcement

```bash
# Get pod names
CATALOG_POD=$(kubectl get pod -l app=catalog-api -n sovereign-seattle -o jsonpath='{.items[0].metadata.name}')
ORDERS_POD=$(kubectl get pod -l app=orders-api -n sovereign-seattle -o jsonpath='{.items[0].metadata.name}')

# ✅ Internal traffic (within sovereign zone) — ALLOWED
kubectl exec $ORDERS_POD -n sovereign-seattle -- \
  curl -s --connect-timeout 5 catalog-api.sovereign-seattle:8080/items

# ❌ External egress (data leaving the zone) — BLOCKED
kubectl exec $CATALOG_POD -n sovereign-seattle -- \
  curl -s --connect-timeout 5 https://httpbin.org/ip

# ❌ Cross-namespace (sovereign → non-sovereign) — BLOCKED
kubectl exec $ORDERS_POD -n sovereign-seattle -- \
  curl -s --connect-timeout 5 catalog-api.cilium-demo:8080/items

# Watch violations in real-time
hubble observe -n sovereign-seattle --verdict DROPPED
```

---

## 📊 Compliance Mapping

| Technical Control | GDPR | CCPA | PIPL | HIPAA | ITAR | FedRAMP |
|-------------------|------|------|------|-------|------|---------|
| Node Affinity (compute pinning) | ✅ Art. 44-49 | ➖ Not required | ✅ Art. 38-39 | ✅ § 164.310 | ✅ § 120.10 | ✅ Required |
| Egress Lockdown (network boundary) | ✅ Art. 32 | ✅ § 1798.150 | ✅ Art. 51 | ✅ § 164.312 | ✅ § 120.17 | ✅ Required |
| Encryption in Transit (WireGuard) | ✅ Art. 32 | ✅ § 1798.150 | ✅ Art. 51 | ✅ § 164.312(e) | ✅ § 120.54 | ✅ Required |
| Namespace Isolation | ✅ Art. 25 | ➖ Best practice | ✅ Art. 51 | ✅ § 164.312(a) | ✅ § 120.10 | ✅ Required |
| Audit Logging (Hubble) | ✅ Art. 30 | ✅ § 1798.185 | ✅ Art. 54 | ✅ § 164.312(b) | ✅ § 122.1 | ✅ Required |
| Default Deny | ✅ Art. 25 | ➖ Best practice | ✅ Art. 51 | ✅ § 164.312(a) | ✅ Required | ✅ Required |

**Key:**
- ✅ = Directly satisfies this regulatory requirement
- ➖ = Not explicitly required, but considered best practice

---

## 🧠 Why eBPF Over Traditional Network Controls?

| Approach | Layer | Bypassable? | Performance | Visibility |
|----------|-------|-------------|-------------|------------|
| **Application middleware** | L7 | ✅ Yes (developer can remove it) | Variable | App logs only |
| **iptables / Security Groups** | L3/L4 | ⚠️ Partially (requires root) | O(n) rule chains | tcpdump |
| **Service mesh (Istio/Linkerd)** | L4-L7 | ⚠️ Partially (sidecar can be bypassed) | High overhead (~100MB/pod) | Mesh metrics |
| **Cilium eBPF** | L3-L7 | ❌ No (kernel-enforced) | O(1) eBPF maps | Hubble (real-time) |

eBPF programs run **inside the Linux kernel**. A compromised application, a malicious library, or even a root-level container escape cannot bypass eBPF network policies without kernel-level access — which container runtimes are specifically designed to prevent.

---

## 🔮 Real-World Deployment Considerations

### Multi-Region Sovereign Zones

In production, you would deploy **separate Kubernetes clusters** per sovereign region, not just separate namespaces:

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  EU Cluster      │  │  US Cluster      │  │  China Cluster   │
│  Frankfurt (FRA) │  │  Seattle (SEA)   │  │  Shanghai (SHA)  │
│  GDPR-compliant  │  │  CCPA-compliant  │  │  PIPL-compliant  │
│  No US egress    │  │  No EU egress    │  │  No foreign      │
│                  │  │                  │  │  egress at all   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                    │                    │
         └────── ClusterMesh (optional, with ──────┘
                 strict cross-border policies)
```

### What This Demo DOESN'T Cover (And You Should Know)

1. **Data at rest encryption** — Use encrypted volumes (LUKS, cloud KMS). Cilium handles data in transit, not at rest.
2. **Key management** — Use HashiCorp Vault or cloud KMS for encryption keys. Keys should be region-locked too.
3. **DNS sovereignty** — In strict environments, use a sovereign DNS resolver (not 8.8.8.8).
4. **Supply chain** — Container images should be pulled from sovereign registries, not Docker Hub.
5. **Human access** — kubectl access should be region-restricted via VPN/bastion hosts.

---

## 📚 Further Reading

- [NIST SP 800-53: Security and Privacy Controls](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [EU GDPR Full Text](https://gdpr-info.eu/)
- [China PIPL Full Text (English)](https://digichina.stanford.edu/work/translation-personal-information-protection-law-of-the-peoples-republic-of-china-effective-nov-1-2021/)
- [Cilium Network Policy Documentation](https://docs.cilium.io/en/stable/security/policy/)
- [Kubernetes Pod Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
- [CISA Zero Trust Maturity Model](https://www.cisa.gov/zero-trust-maturity-model)

---

<p align="center">
  <sub>Built with ☕ and eBPF by <a href="https://github.com/arpanpathak">@arpanpathak</a></sub>
</p>

# OWASP Agentic Security Mapping — Windows Side

AI-Bastion-Guardian addresses OWASP ASI categories from the **Windows perimeter** perspective, complementing AI-Bastion's Linux-side coverage.

Reference: [OWASP Top 10 for Agentic Applications (2026)](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)

---

| ASI # | Risk | Guardian Module | How |
|-------|------|----------------|-----|
| ASI01 | **Agent Behavior Hijacking** | Network-Shield | Blocks external access to agent gateway — prevents remote hijacking |
| ASI02 | **Prompt Injection** | Network-Shield + Egress-Proxy | Network isolation reduces injection vector surface from external sources |
| ASI03 | **Tool Misuse** | Egress-Proxy | Domain whitelist prevents agent from connecting to unauthorized services |
| ASI04 | **Identity & Privilege Abuse** | Credential-Vault | API keys protected in Credential Manager — not in plaintext files |
| ASI05 | **Inadequate Guardrails** | WSL-Fence + Network-Shield | Port exposure detection + firewall enforce network guardrails |
| ASI06 | **Information Disclosure** | Egress-Proxy + Credential-Vault | Outbound control prevents exfiltration. Key encryption prevents theft. |
| ASI07 | **Data Poisoning** | *(Linux-side — AI-Bastion Layer 5)* | Guardian does not address data poisoning directly |
| ASI08 | **DoS & Resource Exhaustion** | WSL-Fence | .wslconfig memory/CPU limits prevent resource exhaustion |
| ASI09 | **Insecure Supply Chain** | Network-Shield | Blocks exposed ports that could be used in supply chain attacks |
| ASI10 | **Over-reliance** | *(Architectural concern)* | Guardian + AI-Bastion together enforce defense-in-depth |

---

## Combined Coverage: Guardian + AI-Bastion

| ASI # | AI-Bastion (Linux) | Guardian (Windows) | Combined |
|-------|-------------------|--------------------|----------|
| ASI01 | ✅ Layers 3, 5, 6 | ✅ Network-Shield | ✅ Full |
| ASI02 | ✅ Layer 3 | ✅ Network isolation | ✅ Full |
| ASI03 | ✅ Layers 1, 4 | ✅ Egress-Proxy | ✅ Full |
| ASI04 | ✅ Layer 7 | ✅ Credential-Vault | ✅ Full |
| ASI05 | ✅ Layers 0, 1 | ✅ WSL-Fence | ✅ Full |
| ASI06 | ✅ Layers 1, 2, 3 | ✅ Egress + Vault | ✅ Full |
| ASI07 | ✅ Layers 3, 5 | ⚠️ Linux-side | ✅ Via AI-Bastion |
| ASI08 | ✅ Layers 1, 4, 6 | ✅ WSL-Fence | ✅ Full |
| ASI09 | ✅ Layers 2, 5 | ✅ Network-Shield | ✅ Full |
| ASI10 | ✅ Layer 6 | ✅ Defense-in-depth | ✅ Full |

**Result: 10/10 ASI categories covered when using both projects together.**

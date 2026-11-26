# Home SOC lab

A personal, self-hosted threat-intelligence lab. In **November 2026** I stood up **OpenCTI** on **Docker Compose** on a Mac, then recovered the stack after a resource-exhaustion outage.

This README is a draft for a planned public repo. It records what was set up and what broke. It does **not** include compose files with credentials, hostnames, IP addresses, API keys or `.env` values.

## What is running

OpenCTI, with:

- Elasticsearch
- RabbitMQ
- Redis
- MinIO
- XTM One
- Connectors for **MITRE ATT&CK** and **ThreatFox**

The stack is up and awaiting more data sources and plugins.

## Outage and fix (November 2026)

After the stack had been running for a long time:

- The Docker daemon became unresponsive
- OpenCTI was unhealthy
- Elasticsearch reported shard errors
- RabbitMQ health checks were timing out and connections were being reset

**Root cause:** resource exhaustion. Elasticsearch was using more than 4 GB of an ~8 GB Docker allocation.

**What I did:**

- Checked the engine and compose status (`docker info`, `docker compose ps`)
- Checked Elasticsearch cluster and shard health
- Trimmed non-essential connectors
- Restarted the services in order
- Verified the service with an HTTP 200

## Lessons learned

- A long-running OpenCTI stack on a laptop-sized Docker allocation can be starved by Elasticsearch heap and shards. Budget memory explicitly, and watch shard health, not only container "up" status.
- Health-check timeouts on RabbitMQ showed up as connection resets once the node was already under memory pressure. Fix the resource limit; do not just restart the one failing container.
- Trimming connectors you are not using is a valid way to get a lab back to a stable baseline before you add more feeds.

## Troubleshooting

- [2026-11-26: MinIO reported unhealthy on `docker compose up`, caused by Elasticsearch starving the Docker VM](docs/troubleshooting/2026-11-26-minio-unhealthy-elasticsearch-memory.md)

## Roadmap (not done)

Capture home-network traffic (for example with **Zeek** or **Suricata**) and feed it into the SOC, to see whether anyone is attacking the home network.

## What this repo will not contain

- `.env` files, passwords, tokens, API keys
- Internal IP addresses or hostnames
- Live telemetry, packet captures, or personal traffic
- Copy-pasted vendor licence keys

If example Compose files are added later, they should use placeholders only.

## Skills this lab exercises

OpenCTI, Docker Compose, Elasticsearch operations, threat-intel connectors (MITRE ATT&CK, ThreatFox), and troubleshooting.

Troubleshooting evidence: [incident write-up on diagnosing a MinIO healthcheck failure under I/O and memory pressure](docs/troubleshooting/2026-11-26-minio-unhealthy-elasticsearch-memory.md) (health logs, `docker stats`, ruling out disk space, root cause and fix).

Built by [Gouresh Kamble](https://github.com/gkambl).

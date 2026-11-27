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

## Lab log

- [2026-11-26: tcpdump baseline and Zeek install](docs/lab-log/2026-11-26-tcpdump-baseline-and-zeek-install.md)
- [2026-11-27: Zeek and Suricata in Docker](docs/lab-log/2026-11-27-zeek-suricata-docker.md)

## Roadmap

Planned pipeline:

```text
network traffic → Zeek / Suricata → alerts / observables → OpenCTI
```

Goal: find out whether anyone is attacking the home network.

**Done (27 Nov 2026):** analysed the 26 Nov pcap with **Zeek** and **Suricata** in Docker, after a Homebrew Zeek install failed on the Intel Mac. About 20 unique external IPv4 destinations; the traffic was expected. Suricata raised two severity-3 alerts for excessive retransmissions on outbound TLS, triaged as benign. Notes: [Zeek and Suricata in Docker](docs/lab-log/2026-11-27-zeek-suricata-docker.md). Helper scripts: [`scripts/zeek-pcap.sh`](scripts/zeek-pcap.sh), [`scripts/suricata-pcap.sh`](scripts/suricata-pcap.sh).

**In progress:** a longer live capture on `en8` (`~/Desktop/live-home-soc.pcap`, local only, not in this repo).

**Not done yet:** feed alerts and observables into OpenCTI.

## What this repo will not contain

- `.env` files, passwords, tokens, API keys
- Internal IP addresses or hostnames
- Live telemetry, packet captures, or personal traffic
- Copy-pasted vendor licence keys

If example Compose files are added later, they should use placeholders only.

## Skills this lab exercises

OpenCTI, Docker Compose, Elasticsearch operations, threat-intel connectors (MITRE ATT&CK, ThreatFox), packet capture with tcpdump, Zeek, Suricata, and troubleshooting.

Troubleshooting evidence: [incident write-up on diagnosing a MinIO healthcheck failure under I/O and memory pressure](docs/troubleshooting/2026-11-26-minio-unhealthy-elasticsearch-memory.md) (health logs, `docker stats`, ruling out disk space, root cause and fix).

Lab log: [tcpdump baseline and Zeek install](docs/lab-log/2026-11-26-tcpdump-baseline-and-zeek-install.md) (SYN vs SYN-ACK filter lesson, local pcap, Intel Homebrew caveat); [Zeek and Suricata in Docker](docs/lab-log/2026-11-27-zeek-suricata-docker.md) (pcap analysis, ET Open rules, alert triage, NDJSON gotcha).

## License

MIT License. See [LICENSE](LICENSE).

Built by [Gouresh Kamble](https://github.com/gkambl).

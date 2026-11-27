# Zeek and Suricata in Docker

**Date:** 2026-11-27 (Europe/Amsterdam) · **Host:** Intel MacBook Pro · **Status:** 26 Nov pcap analysed with Zeek and Suricata; OpenCTI ingestion not started; a live capture is in progress

## Goal

Continue the first stage of the planned pipeline, after the [26 Nov baseline capture](2026-11-26-tcpdump-baseline-and-zeek-install.md):

```text
network traffic → Zeek / Suricata → alerts / observables → OpenCTI
```

The Homebrew Zeek install had been left running overnight. This session records that it failed, switches to Docker, analyses the local pcap with Zeek and Suricata, and starts a longer live capture. Feeding alerts and observables into OpenCTI is still not done.

The pcap files and all Zeek and Suricata output stay on the local machine and are not in this repository.

## Homebrew Zeek install failed

`brew install zeek` did not finish. On this Intel Mac, formulae have to build from source. **openssl@4** alone took **17 hours 53 minutes**. **python@3.15** then built but failed to link, because existing **Python 3.13** framework symlinks were already in `/usr/local/bin`. **sphinx-doc** failed with `No module named pip.__main__`. After that, `zeek` was not on the `PATH` and there was no Zeek keg in the Homebrew cellar.

That matches the Intel caveat in the previous log: a long source build on an unsupported platform is a poor fit for this lab. The rest of the work used Docker instead.

## Zeek in Docker

Pull the official image and replay the 26 Nov pcap, mounting the local Desktop so logs are written on the host:

```bash
docker pull zeek/zeek

docker run --rm \
  -v "$HOME/Desktop:/pcap" \
  -w /pcap \
  zeek/zeek \
  zeek -r incoming-attempts.pcap
```

This produced, locally on the Desktop (not committed):

| File | Size |
| --- | --- |
| `conn.log` | 19K |
| `dns.log` | 9.9K |
| `ssl.log` | 5.1K |
| `weird.log` | 637B |
| `packet_filter.log` | 278B |

The same commands, with a chosen output directory, are in [`scripts/zeek-pcap.sh`](../../scripts/zeek-pcap.sh).

## Gotcha: `zeek-cut` needs `docker run -i`

Piping a log into `zeek-cut` like this printed nothing:

```bash
docker run --rm \
  -v "$HOME/Desktop:/pcap" \
  -w /pcap \
  zeek/zeek \
  zeek-cut id.orig_h id.orig_p id.resp_h id.resp_p proto service duration \
  < conn.log
```

Without `-i`, Docker does not attach the container's stdin, so the redirected file never reaches `zeek-cut`. The fix is to add `-i`:

```bash
docker run --rm -i \
  -v "$HOME/Desktop:/pcap" \
  -w /pcap \
  zeek/zeek \
  zeek-cut id.orig_h id.orig_p id.resp_h id.resp_p proto service duration \
  < conn.log
```

On this pass I cut the columns on the host instead:

```bash
awk -F '\t' '!/^#/ {print $3,$5,$6,$7,$8,$12}' conn.log
```

## Zeek findings

From `conn.log`, `dns.log` and `ssl.log`:

- About **20 unique external IPv4 destinations**.
- Traffic was **dual-stack IPv4 and IPv6**.
- Connections were mostly **TLS on port 443** with `conn_state` **SF** (a normal establishment and teardown). There were also a few **OTH** connections and one **RSTRH**.
- DNS queries went to the **ISP resolver**.
- The SNIs and DNS names were mainly a **dev tool's API** (AWS), an **AI chat service**, **Microsoft telemetry and Defender** cloud endpoints, a **CleanTalk** anti-spam API, and **one company website**.
- On the LAN, there was **mDNS** and **SSDP** from a **smart-home bridge** and the **router**.

Nothing in this short pcap looked unexpected. It is still only the 26 Nov baseline, not a verdict on the home network in general.

## Suricata in Docker

```bash
docker pull jasonish/suricata
```

The image was **Suricata 8.0.8**. The first replay mounted the pcap and a local log directory, with no rules volume:

```bash
docker run --rm \
  -v "$HOME/Desktop:/pcap:ro" \
  -v "$HOME/suricata-home-soc:/var/log/suricata" \
  jasonish/suricata:latest \
  -r /pcap/incoming-attempts.pcap \
  -l /var/log/suricata
```

Suricata warned that no rule files matched and that **no rules were loaded**. It read the same 2,651 packets and reported **0 alerts**. `fast.log` was empty. A first run like this only tells you the engine can read the pcap; it is not a detection pass.

### Fetching ET Open rules

```bash
docker run --rm \
  -v "$HOME/suricata-rules:/var/lib/suricata" \
  jasonish/suricata:latest \
  suricata-update
```

With no extra sources configured, `suricata-update` fetched **Emerging Threats Open**. It loaded **69,582** rules and wrote **53,605** of them as enabled.

It also printed a reload error about a missing command socket (`/var/run/suricata/suricata-command.socket`). That is **harmless in a one-shot container**: there is no long-running Suricata process to reload. The rules were still written, and the command finished with `Done`.

### Re-run with rules

The previous logs were cleared, and the pcap was replayed with the rules directory mounted. This time Suricata loaded **53,605** rules, spent about **0.47s** on the 2,651 packets, and reported **2 alerts**.

Helper script: [`scripts/suricata-pcap.sh`](../../scripts/suricata-pcap.sh).

### Alerts and triage

Both alerts were the same signature:

- SID **2210054**, `SURICATA STREAM excessive retransmissions`
- Category: Generic Protocol Command Decode
- Severity **3**
- Outbound TLS (`to_server`, port 443) from this Mac to the **same dev-tool API server**
- Each flow had **11** retransmissions

A `jq` filter for alerts whose `dest_ip` was `<LAN IP>` returned **none**. There were **no inbound alerts**.

**Triage:** benign network noise, not malicious. Retransmissions on an outbound TLS session to an expected API are not evidence of an attack.

### `jq` vs `python3 -m json.tool`

`eve.json` is **NDJSON**: one JSON object per line. Piping the two alert lines into `python3 -m json.tool` failed with `Extra data: line 2 column 1`, because `json.tool` expects a single JSON document. `jq` reads NDJSON line by line, so it is the right tool here:

```bash
grep '"event_type":"alert"' eve.json | jq -c '{timestamp,src_ip,src_port,dest_ip,dest_port,alert}'

grep '"event_type":"alert"' eve.json | jq -r 'select(.dest_ip=="<LAN IP>") | [.timestamp,.src_ip,.dest_ip,.dest_port,.alert.signature] | @tsv'
```

The second command produced no rows.

## Live capture (in progress)

A longer capture on the same interface is now running and is also local only (not in this repo):

```bash
sudo tcpdump -i en8 -n -w ~/Desktop/live-home-soc.pcap
```

It had not been stopped when these notes were written, so there are no results from it yet.

## Next steps

1. Stop and analyse the live capture with the same Zeek and Suricata Docker workflow.
2. Feed alerts and observables into OpenCTI — this step has not been started.

Pcaps, Zeek logs, Suricata logs (`eve.json`, `fast.log`) and downloaded rule files remain on the local machine.

Earlier notes: [tcpdump baseline and Zeek install](2026-11-26-tcpdump-baseline-and-zeek-install.md). Back to the [lab README](../../README.md).

# tcpdump baseline and Zeek install

**Date:** 2026-11-26 (Europe/Amsterdam) · **Host:** Intel MacBook Pro, default interface `en8` (Ethernet) · **Status:** traffic baseline captured; Zeek install started, not finished. Follow-up: the source build failed overnight; analysis continued in Docker on 27 Nov — see [Zeek and Suricata in Docker](2026-11-27-zeek-suricata-docker.md).

## Goal

Start the first step of the planned pipeline:

```text
network traffic → Zeek / Suricata → alerts / observables → OpenCTI
```

The aim was to capture a short baseline of home-network traffic, check whether any unsolicited inbound TCP connection attempts appeared in that window, and begin installing Zeek so a saved pcap can be analysed later.

## Commands

Find the default interface:

```bash
route get default | grep interface
```

Result: `en8` (Ethernet).

Capture any TCP packet with the SYN bit set:

```bash
sudo tcpdump -i en8 -n 'tcp[tcpflags] & tcp-syn != 0'
```

This showed an outbound SYN with flags `[SEW]` (an ECN-setup SYN) and a matching `[S.E]` SYN-ACK reply from a remote HTTPS server. 2 packets captured, 1,047 received by the filter, 0 dropped.

Narrow the same SYN-bit filter to traffic destined for this host:

```bash
sudo tcpdump -i en8 -n 'dst host <LAN IP> and tcp[tcpflags] & tcp-syn != 0'
```

5 packets captured, 886 received by the filter, 0 dropped. All five were `[S.E]` SYN-ACKs from remote HTTPS servers (port 443) back to this Mac.

Save a full, unfiltered capture locally (not committed to this repo):

```bash
sudo tcpdump -i en8 -n -w ~/Desktop/incoming-attempts.pcap
```

2,651 packets captured, 2,661 received by the filter, 0 dropped by the kernel. The pcap stays on the local Desktop and is not in this repository.

The key test: only inbound packets that are a pure SYN (SYN set, ACK not set):

```bash
sudo tcpdump -i en8 -n 'dst host <LAN IP> and tcp[tcpflags] & (tcp-syn|tcp-ack) == tcp-syn'
```

0 packets captured, 2,410 received by the filter, 0 dropped.

Start installing Zeek 9.0.1 with Homebrew:

```bash
brew install zeek
```

## What the output means

`tcp[tcpflags] & tcp-syn != 0` matches **any** packet with the SYN bit set. That includes both a client's opening SYN and the server's SYN-ACK. It is not a filter for "incoming connection attempts".

That is why the second capture was easy to misread. Filtering to `dst host <LAN IP>` still returned packets, but they were SYN-ACKs (`[S.E]`) from remote port 443. Those are replies to HTTPS connections this Mac had already started, not unsolicited inbound SYNs.

`[SEW]` is a SYN with the ECN-setup flags ECE and CWR. `[S.E]` is the usual SYN-ACK with ECE set in reply. Seeing that pair is normal modern TCP, not a scan.

The filter that actually selects a pure SYN is:

```text
tcp[tcpflags] & (tcp-syn|tcp-ack) == tcp-syn
```

It requires SYN to be set and ACK to be clear. Aimed at `dst host <LAN IP>`, that is the right test for unsolicited inbound TCP connection attempts.

## Findings

In the short window of the pure-SYN test, there were **no unsolicited inbound TCP connection attempts**. Every SYN-bit packet that had been destined for this host in the earlier filter was a SYN-ACK from a remote HTTPS server.

This is a baseline for a brief capture, not a conclusion about the home network in general. A longer capture, and analysis with Zeek or Suricata, is still needed.

The full pcap (`~/Desktop/incoming-attempts.pcap`) is local only and is not in this repository.

## Zeek install notes

`brew install zeek` was started for **Zeek 9.0.1**. It had not finished when these notes were written, so this log does not claim a successful install.

Homebrew warned that **Intel x86_64 macOS is no longer supported** (support ended September 2026, announced August 2025). Homebrew no longer builds bottles for this platform, so Zeek and about 35 formulae — including cmake, llvm and rust — have to be built from source. Existing bottles may still work for some dependencies; cmake 4.5.1 alone took 15 minutes to build. After that, the install continued with further source builds and was still in progress.

Homebrew also warned that the `trufflesecurity/trufflehog` tap is untrusted, and that it is ignoring formulae, casks and commands from that tap until it is trusted or untapped. That warning is unrelated to Zeek itself.

**Alternative:** rather than waiting on a long source build on an unsupported Intel Mac, run Zeek in Docker or in a Linux VM alongside the existing OpenCTI Compose stack. That avoids the Homebrew Intel limitation and keeps the sensor next to the rest of the lab.

## Next steps

The Homebrew Zeek install did not finish. The follow-up session switched to Docker, analysed this pcap with Zeek and Suricata, and started a longer live capture. See [Zeek and Suricata in Docker](2026-11-27-zeek-suricata-docker.md).

Feeding alerts and observables into OpenCTI is still not done.

Back to the [lab README](../../README.md).

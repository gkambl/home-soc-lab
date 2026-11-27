# LAN asset discovery

**Date:** 2026-11-27, about 12:50–13:00 (Europe/Amsterdam) · **Host:** Intel MacBook Pro, interface `en8` · **Status:** asset inventory in progress (5 of 7 devices identified); the two remaining hosts are not yet named

## Goal

Build a first inventory of devices on the home LAN, so confirmed assets can later be registered in OpenCTI and correlated with Zeek and Suricata output. This follows the [Zeek and Suricata pcap analysis](2026-11-27-zeek-suricata-docker.md) from earlier the same day.

No addresses, MAC addresses, hostnames or device serials from this session are recorded here or committed to the repo.

## The ping sweep was a false positive

An nmap ping sweep of the LAN `/24` reported **256/256 hosts up** in **130.59 seconds**, including the **broadcast address**. That is not a credible result on a home network.

`arp -a` told a different story. The ARP table showed only about **five to seven** real neighbours on the LAN, not 256. The likely cause is the **ISP router**, or an **unprivileged scan method**, answering on behalf of addresses that are not actually present.

The more reliable approach on a local Ethernet segment is an ARP ping scan (needs root):

```bash
sudo nmap -sn -PR <subnet>
```

**Lesson:** always verify a sweep against the ARP table before treating "hosts up" as an asset list.

## Filling the ARP cache

The first `arp -a` pass already had several LAN entries, including this Mac (the lab host) and the ISP router. Targeted `ping -c 1` probes then filled out the cache:

```bash
arp -a
ping -c 1 <router>
ping -c 1 <LAN host>
```

After those pings, the ARP table had **seven** LAN entries. One of those hosts **did not answer ping** but was **still in the ARP cache**, so "no ICMP reply" is not enough to drop a neighbour.

## mDNS service discovery

Browse the advertised service types, then look up instances and resolve them to IPv4:

```bash
dns-sd -B _services._dns-sd._udp local
```

The types seen on the LAN were:

| Type | Meaning |
| --- | --- |
| `_hap` | HomeKit Accessory Protocol |
| `_airplay` | AirPlay |
| `_raop` | Remote Audio Output Protocol |
| `_companion-link` | Apple companion-link |
| `_spotify-connect` | Spotify Connect |
| `_hue` | Philips Hue |

```bash
dns-sd -B <type>._tcp local
dns-sd -L "<instance>" <type>._tcp local
dns-sd -G v4 <device>.local.
```

`dns-sd -L` and `dns-sd -G v4` resolved specific instances to IPv4 addresses, which is how the tado bridge and the PlayStation 5 were tied to entries already in the ARP table. Instance names, serials, HomeKit identifiers and `.local` hostnames are kept off this log.

## Asset inventory

**7 devices, 5 identified (71.4%).** Two hosts remain unknown.

| Role | Type | Identified by |
| --- | --- | --- |
| ISP router | Router | Default gateway, ARP, ping |
| Philips Hue bridge | IoT | mDNS (`_hue`), ARP, ping |
| tado internet bridge (smart thermostat) | IoT | mDNS (`_hap` / HomeKit), DNS-SD lookup |
| PlayStation 5 | Gaming | mDNS (`_spotify-connect`), DNS-SD lookup |
| MacBook Pro (lab host) | Endpoint | Local host, mDNS (`_airplay`) |
| Unidentified device | Unknown | ARP only; did not answer ping. Locally administered (randomised / private Wi-Fi) MAC, likely a phone |
| Unidentified device | Unknown | ARP and ping. Locally administered (randomised / private Wi-Fi) MAC, likely a phone |

**Next, on the network side:** rather than more scans, check the **ISP router's connected-devices** page for the two unidentified hosts.

## OpenCTI plan (not done yet)

Add the **confirmed** assets as IPv4 observables in the existing **Home SOC Monitoring** grouping. Reuse existing observables rather than creating duplicates. Suggested labels:

| Asset | Labels |
| --- | --- |
| ISP router | `asset-monitoring`, `asset:router` |
| Philips Hue bridge | `asset-monitoring`, `asset:iot` |
| tado internet bridge | `asset-monitoring`, `asset:iot` |
| PlayStation 5 | `asset-monitoring`, `asset:gaming` |
| MacBook Pro (lab host) | `asset-monitoring`, `asset:endpoint` |

Leave the two unidentified hosts out until they are named.

**Caveat:** registering assets in OpenCTI does not monitor them live. It only builds an inventory for later correlation with alerts and traffic.

## Next steps

1. Identify the two remaining hosts on the ISP router's connected-devices page, then update this inventory.
2. Register the confirmed assets in OpenCTI as planned above. That has not been started.
3. Continue (or later analyse) the live capture from the [Zeek and Suricata session](2026-11-27-zeek-suricata-docker.md), and feed alerts and observables into OpenCTI.

Back to the [lab README](../../README.md).

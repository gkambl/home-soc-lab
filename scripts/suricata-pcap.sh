#!/usr/bin/env bash
# Analyse a local pcap with Suricata in Docker (ET Open rules).
# Usage: scripts/suricata-pcap.sh /path/to/capture.pcap [output-dir] [rules-dir]
#
# Logs and rule files stay on the host and should stay out of git
# (see lab-output/ and eve.json in .gitignore). Do not commit pcaps
# or Suricata output.
#
# suricata-update may print a reload error about a missing command
# socket. That is harmless in this one-shot container: there is no
# long-running Suricata to reload, and the rules are still written.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 /path/to/capture.pcap [output-dir] [rules-dir]" >&2
  exit 1
fi

pcap=$1
out=${2:-./lab-output/suricata}
rules=${3:-./lab-output/suricata-rules}

if [[ ! -f "$pcap" ]]; then
  echo "pcap not found: $pcap" >&2
  exit 1
fi

mkdir -p "$out" "$rules"
pcap_dir=$(cd "$(dirname "$pcap")" && pwd)
pcap_base=$(basename "$pcap")
out_dir=$(cd "$out" && pwd)
rules_dir=$(cd "$rules" && pwd)

docker pull jasonish/suricata

docker run --rm \
  -v "$rules_dir:/var/lib/suricata" \
  jasonish/suricata:latest \
  suricata-update

docker run --rm \
  -v "$pcap_dir:/pcap:ro" \
  -v "$out_dir:/var/log/suricata" \
  -v "$rules_dir:/var/lib/suricata" \
  jasonish/suricata:latest \
  -r "/pcap/$pcap_base" \
  -l /var/log/suricata

echo "Suricata logs written to $out_dir"
# Alerts are in fast.log and as NDJSON in eve.json (one JSON object per
# line; use jq, not python3 -m json.tool, on the whole file):
#   grep '"event_type":"alert"' "$out_dir/eve.json" | jq -c '{timestamp,src_ip,src_port,dest_ip,dest_port,alert}'

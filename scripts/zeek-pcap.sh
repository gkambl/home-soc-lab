#!/usr/bin/env bash
# Analyse a local pcap with Zeek in Docker.
# Usage: scripts/zeek-pcap.sh /path/to/capture.pcap [output-dir]
#
# Logs are written on the host and should stay out of git (see lab-output/
# and *.log in .gitignore). Do not commit pcaps or Zeek output.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 /path/to/capture.pcap [output-dir]" >&2
  exit 1
fi

pcap=$1
out=${2:-./lab-output/zeek}

if [[ ! -f "$pcap" ]]; then
  echo "pcap not found: $pcap" >&2
  exit 1
fi

mkdir -p "$out"
pcap_dir=$(cd "$(dirname "$pcap")" && pwd)
pcap_base=$(basename "$pcap")
out_dir=$(cd "$out" && pwd)

docker pull zeek/zeek

docker run --rm \
  -v "$pcap_dir:/pcap:ro" \
  -v "$out_dir:/zeek-out" \
  -w /zeek-out \
  zeek/zeek \
  zeek -r "/pcap/$pcap_base"

# zeek-cut reads stdin. docker run must include -i, otherwise a redirected
# file never reaches the container and the command prints nothing:
#   docker run --rm -i -v "$out_dir:/zeek-out" -w /zeek-out zeek/zeek \
#     zeek-cut id.orig_h id.resp_h id.resp_p proto service conn_state duration \
#     < "$out_dir/conn.log"
#
# Without Docker, the same columns can be cut on the host:
#   awk -F '\t' '!/^#/ {print $3,$5,$6,$7,$8,$12}' "$out_dir/conn.log"

echo "Zeek logs written to $out_dir"

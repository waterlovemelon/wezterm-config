#!/bin/sh

set -eu

out_file=${1:?missing output path}
cpu_logical=0

case "$(uname -s 2>/dev/null || echo unknown)" in
   Darwin)
      cpu_logical=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 0)
      ;;
   Linux)
      cpu_logical=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 0)
      ;;
   *)
      cpu_logical=${NUMBER_OF_PROCESSORS:-0}
      ;;
esac

case "$cpu_logical" in
   ''|*[!0-9]*)
      cpu_logical=0
      ;;
esac

mkdir -p "$(dirname "$out_file")"

tmp_file="${out_file}.tmp"

cat > "$tmp_file" <<EOF
return {
   cpu_logical = $cpu_logical,
   updated_at = $(date +%s 2>/dev/null || echo 0),
}
EOF

mv "$tmp_file" "$out_file"

#!/usr/bin/env bash
# Collect identifying hardware information from a macOS machine and write two
# markdown fragments: a table row and a collapsible raw dump.
#
# Usage: scripts/macos-hardware.sh [output-dir] [label]
#
#   output-dir  where the fragments are written (default: out)
#   label       name for this machine, e.g. the GitHub runner label
#               (default: the short hostname)
set -euo pipefail

outdir=${1:-out}
label=${2:-$(hostname -s)}

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos-hardware.sh: macOS only; uname -s says '$(uname -s)'" >&2
  exit 1
fi

mkdir -p "$outdir"

# sysctl key -> value, empty string if the key does not exist on this machine
s() { sysctl -n "$1" 2>/dev/null || true; }

# value or an em dash, for table cells
or_dash() { if [ -n "${1:-}" ]; then printf '%s' "$1"; else printf '%s' '—'; fi; }

chip=$(s machdep.cpu.brand_string)
family=$(s hw.cpufamily)
subfamily=$(s hw.cpusubfamily)
physical=$(s hw.physicalcpu)
logical=$(s hw.logicalcpu)
ncpu=$(s hw.ncpu)
pcores=$(s hw.perflevel0.physicalcpu)   # Apple Silicon only
ecores=$(s hw.perflevel1.physicalcpu)   # Apple Silicon only
memsize=$(s hw.memsize)
model=$(s hw.model)
arch=$(uname -m)
osver=$(sw_vers -productVersion 2>/dev/null || true)
osbuild=$(sw_vers -buildVersion 2>/dev/null || true)

# hw.cpufamily/cpusubfamily are stable numeric IDs that still identify the
# silicon generation when the brand string is vague inside a VM. sysctl prints
# them signed; show hex too, masked to 32 bits.
hexify() {
  if [ -n "${1:-}" ]; then printf '%#010x' "$(( $1 & 0xffffffff ))"; else printf '%s' '—'; fi
}
family_hex=$(hexify "$family")
subfamily_hex=$(hexify "$subfamily")

if [ -n "$memsize" ]; then
  mem_h=$(awk -v b="$memsize" 'BEGIN { printf "%.1f GiB", b / 1073741824 }')
else
  mem_h='—'
fi

if [ -n "$pcores" ] && [ -n "$ecores" ]; then
  pe="${pcores}P+${ecores}E"
else
  pe='—'
fi

if [ -n "$osver" ]; then
  os_h="$osver (${osbuild:-?})"
else
  os_h='—'
fi

image="${ImageOS:-—} / ${ImageVersion:-—}"

# shellcheck disable=SC2016  # backticks here are markdown, not command substitution
printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
  "$label" \
  "$(or_dash "$chip")" \
  "$(or_dash "$physical")" \
  "$pe" \
  "$mem_h" \
  "$(or_dash "$arch")" \
  "$os_h" \
  "$(or_dash "$model")" \
  "$family_hex" \
  "$image" \
  > "${outdir}/row-${label}.md"

{
  printf '<details>\n'
  printf '<summary><code>%s</code> — raw detail</summary>\n\n' "$label"
  printf '```\n'
  printf 'label                     %s\n' "$label"
  printf 'machdep.cpu.brand_string  %s\n' "$(or_dash "$chip")"
  printf 'hw.cpufamily              %s (%s)\n' "$(or_dash "$family")" "$family_hex"
  printf 'hw.cpusubfamily           %s (%s)\n' "$(or_dash "$subfamily")" "$subfamily_hex"
  printf 'hw.physicalcpu            %s\n' "$(or_dash "$physical")"
  printf 'hw.logicalcpu             %s\n' "$(or_dash "$logical")"
  printf 'hw.ncpu                   %s\n' "$(or_dash "$ncpu")"
  printf 'hw.perflevel0.physicalcpu %s\n' "$(or_dash "$pcores")"
  printf 'hw.perflevel1.physicalcpu %s\n' "$(or_dash "$ecores")"
  printf 'hw.memsize                %s (%s)\n' "$(or_dash "$memsize")" "$mem_h"
  printf 'hw.model                  %s\n' "$(or_dash "$model")"
  printf 'uname -m                  %s\n' "$arch"
  printf 'sw_vers                   %s\n' "$os_h"
  printf 'ImageOS / ImageVersion    %s\n' "$image"
  printf 'RUNNER_ARCH               %s\n' "${RUNNER_ARCH:-—}"
  printf '```\n\n'

  printf '<details><summary>system_profiler SPHardwareDataType</summary>\n\n'
  printf '```\n'
  system_profiler SPHardwareDataType 2>/dev/null || echo '(unavailable)'
  printf '```\n'
  printf '</details>\n\n'

  printf '<details><summary>sysctl hw machdep.cpu</summary>\n\n'
  printf '```\n'
  sysctl hw machdep.cpu 2>/dev/null || echo '(unavailable)'
  printf '```\n'
  printf '</details>\n\n'

  printf '<details><summary>df -h /</summary>\n\n'
  printf '```\n'
  df -h / 2>/dev/null || echo '(unavailable)'
  printf '```\n'
  printf '</details>\n\n'

  printf '</details>\n'
} > "${outdir}/details-${label}.md"

echo "macos-hardware.sh: wrote ${outdir}/row-${label}.md and ${outdir}/details-${label}.md" >&2

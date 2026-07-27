#!/bin/bash
set -euo pipefail
export PATH=/usr/sbin:/sbin:/usr/bin:/bin
POOL=snow
KEEP_DAYS=7
zfs snapshot -r "${POOL}@auto-$(date +%Y%m%d-%H%M%S)"
now=$(date +%s)
zfs list -H -p -t snapshot -d 1 -o name,creation "$POOL" | while read -r name creation; do
  case "$name" in
    *@auto-*)
      if [ $(( (now - creation) / 86400 )) -ge "$KEEP_DAYS" ]; then
        zfs destroy -r "$name"
      fi
      ;;
  esac
done

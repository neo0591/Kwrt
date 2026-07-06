#!/bin/bash
# Apply Kwrt patches: common (strict) + per-target device patches (best-effort).
# Device patches often drift against moving OpenWrt 25.12; failures are warnings only.
set -euo pipefail

ROOT="${1:-.}"
TARGET="${2:-}"

COMMON_DIR="${ROOT}/devices/common/patches"
DEVICE_DIR="${ROOT}/devices/${TARGET}/patches"

apply_dir() {
  local dir="$1"
  local strict="$2"
  local name failed=0

  [ -d "$dir" ] || return 0
  name="$(basename "$(dirname "$dir")")/$(basename "$dir")"
  echo "== apply-patches: ${name} (strict=${strict}) =="

  while IFS= read -r -d '' p; do
    echo "revert: $p"
    patch -d "$ROOT" -R -b -p1 -f --ignore-whitespace -i "$p" || {
      echo "::warning::revert failed: $p"
      [ "$strict" -eq 1 ] && exit 1
    }
  done < <(find "$dir" -maxdepth 1 -type f -name '*.revert.patch' -print0 | sort -z)

  if [ -n "$(find "$dir" -maxdepth 1 -name '*.bin.patch' -print0 | head -c1)" ]; then
    echo "git apply bin patches in $dir"
    git -C "$ROOT" apply --ignore-whitespace "$dir"/*.bin.patch || {
      echo "::warning::bin.patch apply failed in $dir"
      [ "$strict" -eq 1 ] && exit 1
    }
  fi

  while IFS= read -r -d '' p; do
    echo "patch: $p"
    if patch -d "$ROOT" -b -p1 -f --ignore-whitespace -i "$p"; then
      echo "ok: $p"
    else
      failed=$((failed + 1))
      echo "::warning::patch failed (non-fatal=${strict}): $p"
      [ "$strict" -eq 1 ] && exit 1
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.patch' ! -name '*.revert.patch' ! -name '*.bin.patch' -print0 | sort -z)

  if [ "$failed" -gt 0 ] && [ "$strict" -eq 0 ]; then
    echo "::warning::${failed} patch(es) failed in ${name} — continuing (diy/ + upstream may cover devices)"
  fi
}

cd "$ROOT"
apply_dir "$COMMON_DIR" 1
if [ -n "$TARGET" ]; then
  apply_dir "$DEVICE_DIR" 0
fi
echo "apply-patches: done"

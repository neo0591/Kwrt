#!/bin/bash
# Apply NeoWrt online build customization (init script, custom files, extra packages).
set -euo pipefail

BUILD_ID="${NEOWRT_BUILD_ID:-}"
[ -z "$BUILD_ID" ] && { echo "neowrt-apply: no build_id, skip"; exit 0; }

REPO="${GITHUB_REPOSITORY:-neo0591/Kwrt}"
TOKEN="${TOKEN_KIDDIN9:-${GITHUB_TOKEN:-}}"
WORKSPACE="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/../../.." && pwd)}"
BUNDLE_DIR="$WORKSPACE/neowrt-builds/$BUILD_ID"

mkdir -p "$BUNDLE_DIR"

download_repo_file() {
  local name="$1"
  local dest="$BUNDLE_DIR/$name"
  if [ -f "$dest" ]; then
    return 0
  fi
  if [ -z "$TOKEN" ]; then
    echo "neowrt-apply: missing token, cannot download $name"
    return 1
  fi
  curl -fsSL \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/contents/neowrt-builds/$BUILD_ID/$name" \
    | jq -r '.content' | tr -d '\n' | base64 -d > "$dest"
}

echo "neowrt-apply: build_id=$BUILD_ID"
download_repo_file manifest.json

MANIFEST="$BUNDLE_DIR/manifest.json"
DEFAULTS="$(jq -r '.defaults // ""' "$MANIFEST")"
CUSTOM_FILE="$(jq -r '.customFiles // empty' "$MANIFEST")"
PACKAGES_JSON="$(jq -c '.packages // []' "$MANIFEST")"

mkdir -p files/etc/uci-defaults files/root/neowrt-ipk

if [ -n "$DEFAULTS" ]; then
  {
    echo '#!/bin/sh'
    echo '# NeoWrt custom init (first boot)'
    printf '%s\n' "$DEFAULTS"
    echo 'exit 0'
  } > files/etc/uci-defaults/99-neowrt-init.sh
  chmod +x files/etc/uci-defaults/99-neowrt-init.sh
  echo "neowrt-apply: wrote files/etc/uci-defaults/99-neowrt-init.sh"
fi

if [ -n "$CUSTOM_FILE" ]; then
  download_repo_file "$CUSTOM_FILE"
  ARCHIVE="$BUNDLE_DIR/$CUSTOM_FILE"
  EXTRACT_DIR="$BUNDLE_DIR/extracted"
  rm -rf "$EXTRACT_DIR"
  mkdir -p "$EXTRACT_DIR"

  case "$ARCHIVE" in
    *.zip) unzip -qo "$ARCHIVE" -d "$EXTRACT_DIR" ;;
    *.tar.gz|*.tgz) tar -xzf "$ARCHIVE" -C "$EXTRACT_DIR" ;;
    *.7z)
      if command -v 7z >/dev/null 2>&1; then
        7z x -o"$EXTRACT_DIR" "$ARCHIVE" >/dev/null
      elif command -v 7za >/dev/null 2>&1; then
        7za x -o"$EXTRACT_DIR" "$ARCHIVE" >/dev/null
      else
        echo "neowrt-apply: 7z not available for $CUSTOM_FILE"
        exit 1
      fi
      ;;
    *)
      echo "neowrt-apply: unsupported archive $CUSTOM_FILE"
      exit 1
      ;;
  esac

  while IFS= read -r -d '' ipk; do
    pkg="$(basename "$ipk" .ipk)"
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
    mv "$ipk" "files/root/neowrt-ipk/"
    echo "neowrt-apply: queued ipk $pkg"
  done < <(find "$EXTRACT_DIR" -name '*.ipk' -print0)

  if [ -n "$(find "$EXTRACT_DIR" -type f ! -name '*.ipk' -print -quit)" ]; then
    cp -a "$EXTRACT_DIR/." files/
    echo "neowrt-apply: merged custom files into overlay"
  fi
fi

if [ "$(find files/root/neowrt-ipk -name '*.ipk' -print -quit 2>/dev/null)" ]; then
  cat > files/etc/uci-defaults/98-neowrt-ipk.sh <<'EOF'
#!/bin/sh
for ipk in /root/neowrt-ipk/*.ipk; do
  [ -f "$ipk" ] || continue
  opkg install "$ipk" && rm -f "$ipk"
done
rmdir /root/neowrt-ipk 2>/dev/null || true
exit 0
EOF
  chmod +x files/etc/uci-defaults/98-neowrt-ipk.sh
fi

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  if [[ "$pkg" == -* ]]; then
    name="${pkg#-}"
    echo "CONFIG_PACKAGE_${name}=n" >> .config
    echo "neowrt-apply: remove package $name"
  else
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
    echo "neowrt-apply: add package $pkg"
  fi
done < <(jq -r '.[]' <<<"$PACKAGES_JSON")

echo "neowrt-apply: done"

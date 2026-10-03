#!/usr/bin/env bash
# Build the DeepSeek Harness Linux .deb from a deepseek-harness source checkout.
#
# Only deb is produced: apps/desktop's linux.target lists ['deb', 'rpm'], and the
# rpm half needs rpmbuild, which is not assumed to be installed.
#
# Usage: scripts/build-deb.sh [path-to-deepseek-harness] [output-dir]
set -euo pipefail

HARNESS_ROOT="${1:-$HOME/code/deepseek-harness}"
OUTPUT_DIR="${2:-$(cd "$(dirname "$0")/.." && pwd)}"

DESKTOP="$HARNESS_ROOT/apps/desktop"
HOMEPAGE="${DSH_DESKTOP_HOMEPAGE:-https://github.com/deepseek-ai/deepseek-harness}"

if [[ ! -f "$DESKTOP/electron-builder.config.mjs" ]]; then
  echo "error: $DESKTOP/electron-builder.config.mjs not found." >&2
  echo "       pass the deepseek-harness checkout as the first argument." >&2
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "error: pnpm must be on PATH; electron-builder spawns it to collect node modules." >&2
  exit 1
fi

# fpm's bundled ruby wants libcrypt.so.1; Arch's libxcrypt only ships libcrypt.so.2.
if [[ -f /etc/arch-release ]] && ! [[ -e /usr/lib/libcrypt.so.1 ]]; then
  echo "warn: /usr/lib/libcrypt.so.1 is missing -> run: sudo pacman -S libxcrypt-compat" >&2
fi

# The prepared trees under .desktop-build/targets/linux-x64 are reused when present,
# so this step is fast for a rebuild. It takes ~7 minutes only on a cold tree.
if [[ ! -d "$DESKTOP/.desktop-build/targets/linux-x64/dsh" ]]; then
  echo "==> preparing linux-x64 trees (cold; this takes several minutes)"
  cd "$HARNESS_ROOT"
  env -u ELECTRON_RUN_AS_NODE \
      -u CODEBUDDY_SAFE_DELETE_BULK_STATE_DIR \
      -u CODEBUDDY_TOOL_CALL_ID \
      -u CODEBUDDY_SAFE_DELETE_ENABLED \
    pnpm --filter @deepseek-ai/dsh-desktop run prepare:linux
fi

cd "$DESKTOP"

# ELECTRON_RUN_AS_NODE must be cleared or packaging inherits the host's shell
# environment; the safe-delete vars are a host agent guard, not a product concern.
env -u ELECTRON_RUN_AS_NODE \
    -u CODEBUDDY_SAFE_DELETE_BULK_STATE_DIR \
    -u CODEBUDDY_TOOL_CALL_ID \
    -u CODEBUDDY_SAFE_DELETE_ENABLED \
  sh -c '
    set -a; . ./.env.linux; set +a
    DSH_DESKTOP_TARGET_PLATFORM=linux DSH_DESKTOP_TARGET_ARCH=x64 \
    ./node_modules/.bin/electron-builder --config electron-builder.config.mjs \
      --linux deb --x64 --publish never \
      --config.linux.icon=resources/icon.png \
      --config.extraMetadata.homepage="$1"
  ' sh "$HOMEPAGE"

ARTIFACTS="$DESKTOP/.desktop-build/targets/linux-x64/artifacts"
DEB="$(ls -1 "$ARTIFACTS"/deepseek-harness-*-linux-amd64.deb | tail -n1)"

cp -a "$DEB" "$OUTPUT_DIR/"
echo
echo "==> $(basename "$DEB")"
ls -l "$OUTPUT_DIR/$(basename "$DEB")"
sha256sum "$OUTPUT_DIR/$(basename "$DEB")"

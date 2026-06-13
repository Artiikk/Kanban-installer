#!/usr/bin/env bash
# BccVibe CLI installer (GitHub releases, private-repo capable).
#
# This script carries no secrets and is meant to be hosted PUBLICLY (a public
# installer repo, a gist, or any static host) so the `curl … | bash` one-liner
# resolves. The release archives themselves stay in the PRIVATE repo; this
# script fetches them with a GitHub token via the releases API — the
# `releases/latest/download/<asset>` browser path 404s for private repos, so
# we go through `api.github.com/.../releases/assets/<id>` with auth instead.
#
# Auth (pick one):
#   • `gh auth login` beforehand — no token env needed (preferred), or
#   • export BCC_VIBE_TOKEN=<github PAT with `repo` read access>
#     (GITHUB_TOKEN / GH_TOKEN are also accepted)
#
# Overrides: BCC_VIBE_REPO (default Artiikk/BCC-Vibe-Kanban),
#            BCC_VIBE_INSTALL_DIR (default /usr/local/bin or ~/.local/bin).
set -euo pipefail

REPO="${BCC_VIBE_REPO:-Artiikk/BCC-Vibe-Kanban}"
BINARY="bcc-vibe"
TOKEN="${BCC_VIBE_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"

err() { echo "install: $*" >&2; exit 1; }
note() { echo "install: $*" >&2; }

# ── Platform detection (mirrors the desktop bootstrap's asset selector) ──────
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) arch=amd64 ;;
  arm64|aarch64) arch=arm64 ;;
  *) err "unsupported architecture: $arch" ;;
esac
case "$os" in
  darwin|linux) ;;
  *) err "unsupported OS: $os (use install.ps1 on Windows)" ;;
esac
SUFFIX="-${os}-${arch}.tar.gz"
LEGACY="bcc_vibe_${os}_${arch}.tar.gz"

# ── Backend: gh CLI if authenticated, else token + jq via the REST API ───────
BACKEND=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  BACKEND="gh"
elif [ -n "$TOKEN" ]; then
  command -v jq >/dev/null 2>&1 || err "the token path needs 'jq' — install it (brew install jq / apt-get install jq) or run 'gh auth login' instead"
  BACKEND="api"
else
  err "no GitHub auth found. Either run 'gh auth login', or export BCC_VIBE_TOKEN=<github PAT>"
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
RELEASE_JSON="$WORKDIR/release.json"

list_assets() {
  if [ "$BACKEND" = "gh" ]; then
    gh release view --repo "$REPO" --json assets --jq '.assets[].name'
  else
    curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$REPO/releases/latest" -o "$RELEASE_JSON" \
      || err "could not read latest release of $REPO (check the token has read access)"
    jq -r '.assets[].name' "$RELEASE_JSON"
  fi
}

download_asset() {  # $1 = asset name, $2 = dest path
  local name="$1" dest="$2"
  if [ "$BACKEND" = "gh" ]; then
    gh release download --repo "$REPO" --pattern "$name" --output "$dest" --clobber \
      || err "gh failed to download $name"
  else
    local url
    url="$(jq -r --arg n "$name" '.assets[]|select(.name==$n)|.url' "$RELEASE_JSON")"
    [ -n "$url" ] && [ "$url" != "null" ] || err "asset $name not found in release"
    # -L strips the Authorization header on the cross-host redirect to the
    # asset CDN by default, which is exactly what the storage backend wants.
    curl -fsSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/octet-stream" \
      -L "$url" -o "$dest" || err "download failed for $name"
  fi
}

# ── Select the archive for this platform ─────────────────────────────────────
# Read into an array without `mapfile` (absent in bash 3.2, macOS's default).
ASSETS=()
while IFS= read -r line; do
  [ -n "$line" ] && ASSETS+=("$line")
done < <(list_assets)
[ "${#ASSETS[@]}" -gt 0 ] || err "no assets on the latest release of $REPO"

asset=""
for name in "${ASSETS[@]}"; do
  case "$name" in
    bcc-vibe-cli-*"$SUFFIX") asset="$name"; break ;;
  esac
done
if [ -z "$asset" ]; then
  for name in "${ASSETS[@]}"; do
    [ "$name" = "$LEGACY" ] && { asset="$LEGACY"; break; }
  done
fi
[ -n "$asset" ] || err "no release asset for ${os}/${arch} (looked for *${SUFFIX} or ${LEGACY})"

# ── Download archive + checksums, verify, extract ────────────────────────────
note "downloading $asset"
download_asset "$asset" "$WORKDIR/$asset"

if printf '%s\n' "${ASSETS[@]}" | grep -qx "checksums.txt"; then
  download_asset "checksums.txt" "$WORKDIR/checksums.txt"
  expected="$(awk -v f="$asset" '$2 ~ ("\\*?" f "$") {print $1}' "$WORKDIR/checksums.txt" | head -n1)"
  [ -n "$expected" ] || err "no checksum entry for $asset in checksums.txt"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$WORKDIR/$asset" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$WORKDIR/$asset" | awk '{print $1}')"
  fi
  [ "$actual" = "$expected" ] || err "checksum mismatch for $asset (expected $expected, got $actual)"
  note "checksum verified"
else
  note "warning: release has no checksums.txt — skipping integrity check"
fi

tar -xzf "$WORKDIR/$asset" -C "$WORKDIR" || err "failed to extract $asset"
[ -f "$WORKDIR/$BINARY" ] || err "archive $asset did not contain $BINARY at its root"
chmod +x "$WORKDIR/$BINARY"

# ── Install ──────────────────────────────────────────────────────────────────
if [ -n "${BCC_VIBE_INSTALL_DIR:-}" ]; then
  bindir="$BCC_VIBE_INSTALL_DIR"
elif [ -w /usr/local/bin ]; then
  bindir=/usr/local/bin
else
  bindir="$HOME/.local/bin"
fi
mkdir -p "$bindir"
mv "$WORKDIR/$BINARY" "$bindir/$BINARY"

# macOS: ad-hoc sign so Gatekeeper never blocks the freshly-moved binary.
if [ "$os" = "darwin" ] && command -v codesign >/dev/null 2>&1; then
  codesign -s - --force "$bindir/$BINARY" >/dev/null 2>&1 || true
fi

note "installed: $bindir/$BINARY"
case ":${PATH}:" in
  *":${bindir}:"*) ;;
  *) note "add $bindir to your PATH: export PATH=\"$bindir:\$PATH\"" ;;
esac
echo "Next: bcc-vibe setup"

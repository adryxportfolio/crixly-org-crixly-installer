#!/usr/bin/env bash
set -euo pipefail

# Crixly one-liner installer (macOS/Linux)
# Installs a local Crixly prefix with bundled Node + Crixly CLI, then runs onboarding.

PREFIX_DEFAULT="$HOME/.crixly"
PREFIX="${CRIXLY_PREFIX:-$PREFIX_DEFAULT}"
NODE_VERSION="${CRIXLY_NODE_VERSION:-22.22.0}"

CRIXLY_SUPABASE_URL_DEFAULT="https://zwlknecauwiqmmpxyezt.supabase.co"
CRIXLY_SUPABASE_URL="${CRIXLY_SUPABASE_URL:-$CRIXLY_SUPABASE_URL_DEFAULT}"
CRIXLY_SUPABASE_ANON_KEY="${CRIXLY_SUPABASE_ANON_KEY:-}"

usage() {
  cat <<EOF
Usage: install.sh [--prefix PATH] [--no-onboard]

Env:
  CRIXLY_PREFIX              Install prefix (default: ~/.crixly)
  CRIXLY_NODE_VERSION        Node version for local runtime (default: $NODE_VERSION)
  CRIXLY_SUPABASE_URL        Supabase URL (default: $CRIXLY_SUPABASE_URL_DEFAULT)
  CRIXLY_SUPABASE_ANON_KEY   Supabase anon key (required)
  CRIXLY_LICENSE_KEY         License key (required to run)
EOF
}

NO_ONBOARD=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2;;
    --no-onboard) NO_ONBOARD=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 2;;
  esac
done

if [[ -z "$CRIXLY_SUPABASE_ANON_KEY" ]]; then
  echo "CRIXLY_SUPABASE_ANON_KEY is required." >&2
  exit 2
fi

mkdir -p "$PREFIX/tools" "$PREFIX/bin" "$PREFIX/app"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Darwin) PLATFORM="darwin";;
  Linux) PLATFORM="linux";;
  *) echo "Unsupported OS: $OS"; exit 2;;
esac

case "$ARCH" in
  x86_64|amd64) ARCH2="x64";;
  arm64|aarch64) ARCH2="arm64";;
  *) echo "Unsupported arch: $ARCH"; exit 2;;
esac

NODE_DIR="$PREFIX/tools/node-v$NODE_VERSION"
NODE_BIN="$NODE_DIR/bin/node"
NPM_BIN="$NODE_DIR/bin/npm"

if [[ ! -x "$NODE_BIN" ]]; then
  echo "Installing Node $NODE_VERSION..."
  TMP="$(mktemp -d)"
  TARBALL="node-v$NODE_VERSION-$PLATFORM-$ARCH2.tar.gz"
  URL="https://nodejs.org/dist/v$NODE_VERSION/$TARBALL"
  curl -fsSL "$URL" -o "$TMP/$TARBALL"
  mkdir -p "$NODE_DIR"
  tar -xzf "$TMP/$TARBALL" -C "$TMP"
  # Node archives contain a directory node-vX.Y.Z-plat-arch
  mv "$TMP/node-v$NODE_VERSION-$PLATFORM-$ARCH2"/* "$NODE_DIR/"
  rm -rf "$TMP"
fi

# Install Crixly CLI from a packaged tarball URL (placeholder for now)
# TODO: replace with your hosted release artifact URL.
CRIXLY_TGZ_URL="${CRIXLY_TGZ_URL:-}"
if [[ -z "$CRIXLY_TGZ_URL" ]]; then
  echo "CRIXLY_TGZ_URL is not set (URL to crixly-cli tgz release)." >&2
  echo "For now, build/publish crixly-cli and set CRIXLY_TGZ_URL." >&2
  exit 2
fi

echo "Installing Crixly CLI..."
"$NPM_BIN" install --prefix "$PREFIX/app" "$CRIXLY_TGZ_URL" >/dev/null

cat > "$PREFIX/bin/crixly" <<EOF
#!/usr/bin/env bash
export CRIXLY_SUPABASE_URL="$CRIXLY_SUPABASE_URL"
export CRIXLY_SUPABASE_ANON_KEY="$CRIXLY_SUPABASE_ANON_KEY"
exec "$NODE_BIN" "$PREFIX/app/node_modules/crixly-cli/dist/index.js" "$@"
EOF
chmod +x "$PREFIX/bin/crixly"

echo "Installed. Add to PATH:"
echo "  export PATH=\"$PREFIX/bin:\$PATH\""

if [[ "$NO_ONBOARD" -eq 0 ]]; then
  echo "Running: crixly onboard"
  "$PREFIX/bin/crixly" onboard
fi

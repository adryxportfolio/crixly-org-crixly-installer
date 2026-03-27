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

mkdir -p "$PREFIX/tools" "$PREFIX/bin" "$PREFIX/app" "$PREFIX/workspace"

# Workspace path for Crixly
export CRIXLY_WORKSPACE="$PREFIX/workspace"

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
CRIXLY_TGZ_URL="${CRIXLY_TGZ_URL:-https://raw.githubusercontent.com/adryxportfolio/crixly-org-crixly-installer/main/releases/crixly-cli-latest.tgz}"
# When Cloudflare Pages is live, you can override with:
# CRIXLY_TGZ_URL=https://install.crixly.org/releases/crixly-cli-latest.tgz

echo "Installing Crixly CLI..."
"$NPM_BIN" install --prefix "$PREFIX/app" "$CRIXLY_TGZ_URL" >/dev/null

# Install bundled skills
if [[ -d "$(dirname "$0")/../bundled-skills" ]]; then
  echo "Installing bundled skills..."
  mkdir -p "$PREFIX/workspace/skills"
  cp -R "$(dirname "$0")/../bundled-skills"/* "$PREFIX/workspace/skills/" || true
fi

# Write default config
mkdir -p "$PREFIX/app/config"
cat > "$PREFIX/app/config/crixly.default.json" <<'JSON'
{
  "gateway": { "port": 27811, "mode": "local", "bind": "loopback", "auth": { "mode": "token" } },
  "agents": { "defaults": { "workspace": "${CRIXLY_WORKSPACE}" } }
}
JSON

cat > "$PREFIX/bin/crixly" <<EOF
#!/usr/bin/env bash
export CRIXLY_SUPABASE_URL="$CRIXLY_SUPABASE_URL"
export CRIXLY_SUPABASE_ANON_KEY="$CRIXLY_SUPABASE_ANON_KEY"
export CRIXLY_WORKSPACE="$PREFIX/workspace"
# Underlying runtime will read this config path once we bundle runtime.
exec "$NODE_BIN" "$PREFIX/app/node_modules/crixly-cli/dist/index.js" "$@"
EOF
chmod +x "$PREFIX/bin/crixly"

echo "Installed. Add to PATH:"
echo "  export PATH=\"$PREFIX/bin:\$PATH\""

echo "Next steps:"
echo "  crixly activate <LICENSE_KEY>"
echo "  crixly run"
echo "Dashboard: http://127.0.0.1:27811"

if [[ "$NO_ONBOARD" -eq 0 ]]; then
  echo "Running: crixly activate <LICENSE_KEY> (required)"
fi

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== ben-digest setup ==="
echo "Project dir: $PROJECT_DIR"

# ── Detect architecture ──────────────────────────────────────────────
ARCH=$(uname -m)
echo "Architecture: $ARCH"

# ── Zig ──────────────────────────────────────────────────────────────
if command -v zig &>/dev/null; then
    ZIG_VER=$(zig version)
    echo "Zig found: $ZIG_VER"
    if [[ "$ZIG_VER" != "0.15.2" ]]; then
        echo "WARNING: Expected Zig 0.15.2, got $ZIG_VER"
        echo "Install with: brew install zig"
    fi
else
    echo "Installing Zig via Homebrew..."
    brew install zig
fi

# ── Build nullclaw ───────────────────────────────────────────────────
echo ""
echo "Building nullclaw..."
cd "$PROJECT_DIR/nullclaw"
zig build -Doptimize=ReleaseSmall
BINARY="$PROJECT_DIR/nullclaw/zig-out/bin/nullclaw"
if [[ -f "$BINARY" ]]; then
    SIZE=$(du -h "$BINARY" | cut -f1)
    echo "Built: $BINARY ($SIZE)"
else
    echo "ERROR: Build failed — binary not found"
    exit 1
fi

# ── Python + venv ────────────────────────────────────────────────────
echo ""
echo "Setting up Python virtual environment..."
if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 not found. Install with: brew install python3"
    exit 1
fi

cd "$PROJECT_DIR/twitter-poller"
python3 -m venv .venv
source .venv/bin/activate
pip install -q -r requirements.txt
echo "Python deps installed in .venv"

# ── Tailscale ────────────────────────────────────────────────────────
echo ""
if command -v tailscale &>/dev/null; then
    echo "Tailscale found: $(tailscale version 2>/dev/null | head -1)"
else
    echo "Tailscale not found. Install with: brew install --cask tailscale"
fi

# ── Config dir ───────────────────────────────────────────────────────
echo ""
mkdir -p ~/.nullclaw
echo "Config dir: ~/.nullclaw"

echo ""
echo "=== Setup complete ==="
echo "Next: run scripts/onboard.sh to configure credentials"

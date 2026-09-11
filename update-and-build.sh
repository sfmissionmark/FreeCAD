#!/usr/bin/env bash
# Pull the latest commits on the current branch, then build/install FreeCAD
# via pixi and (on macOS) make the result Finder's default .FCStd handler.
#
# Meant to be dropped into any checkout of this repo and just run:
#   ./update-and-build.sh
# Safe to re-run any time -- it no-ops the git pull if the tree is dirty
# or detached, and the build/install steps are incremental.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

if [[ ! -d .git ]]; then
  echo "error: $PROJECT_DIR is not a git checkout" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree has uncommitted changes -- skipping 'git pull', building as-is."
else
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$BRANCH" == "HEAD" ]]; then
    echo "Detached HEAD -- skipping 'git pull', building as-is."
  else
    echo "Updating branch '$BRANCH'..."
    git pull --ff-only
  fi
fi

if ! command -v pixi >/dev/null 2>&1; then
  echo "error: pixi not found on PATH." >&2
  echo "Install it first: curl -fsSL https://pixi.sh/install.sh | bash" >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    bash tools/macos-dev-build-install.sh debug
    ;;
  *)
    pixi run configure
    pixi run build
    pixi run install
    ;;
esac

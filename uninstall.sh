#!/usr/bin/env bash
#
# uninstall.sh — Remove this repo's skill symlinks from the global Kiro dir.
#
# Only removes symlinks in ~/.kiro/skills/ that point into THIS repo's skills/
# directory. Real folders and links owned by other sources are left untouched.
# It also removes the git post-merge hook configuration.
#
# Usage:
#   ./uninstall.sh
#
# Override the destination with KIRO_SKILLS_DIR:
#   KIRO_SKILLS_DIR=/tmp/skills ./uninstall.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DST="${KIRO_SKILLS_DIR:-$HOME/.kiro/skills}"

# Whole-directory mode: ~/.kiro/skills is itself a symlink into this repo.
if [ -L "$SKILLS_DST" ]; then
  dest="$(readlink "$SKILLS_DST")"
  if [ "$dest" = "$SKILLS_SRC" ]; then
    rm "$SKILLS_DST"
    echo "removed: $SKILLS_DST -> $SKILLS_SRC (whole-directory symlink)"
  else
    echo "note: $SKILLS_DST is a symlink to $dest (not this repo) — left untouched."
  fi
else
  removed=0
  if [ -d "$SKILLS_DST" ]; then
    for link in "$SKILLS_DST"/*; do
      [ -L "$link" ] || continue
      dest="$(readlink "$link")"
      case "$dest" in
        "$SKILLS_SRC"/*)
          rm "$link"
          echo "unlinked: $(basename "$link")"
          removed=$((removed + 1))
          ;;
      esac
    done
  fi
  echo "Done. removed=$removed symlink(s)."
fi

# Remove the local git hook configuration if we set it.
if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if [ "$(git -C "$REPO_DIR" config --local core.hooksPath || true)" = ".githooks" ]; then
    git -C "$REPO_DIR" config --local --unset core.hooksPath
    echo "hook:    removed post-merge hook configuration"
  fi
fi

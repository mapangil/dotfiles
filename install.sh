#!/usr/bin/env bash
#
# install.sh — Link every skill in this repo into the global Kiro skills dir.
#
# Symlinks each directory under ./skills/ into ~/.kiro/skills/ so Kiro
# discovers them globally. Idempotent: safe to re-run. It creates missing
# links, repoints stale ones, skips correct ones, and warns on real (non-symlink)
# directories so nothing is clobbered.
#
# It also installs a git post-merge hook (via core.hooksPath) so this script
# runs automatically after every `git pull` — new skills link themselves.
#
# Usage:
#   ./install.sh
#
# Override the destination (e.g. for testing) with KIRO_SKILLS_DIR:
#   KIRO_SKILLS_DIR=/tmp/skills ./install.sh
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DST="${KIRO_SKILLS_DIR:-$HOME/.kiro/skills}"

if [ ! -d "$SKILLS_SRC" ]; then
  echo "error: no skills/ directory found at $SKILLS_SRC" >&2
  exit 1
fi

# If the global skills dir is itself a symlink, the user chose whole-directory
# mode (~/.kiro/skills -> repo/skills). Per-skill linking is unnecessary.
if [ -L "$SKILLS_DST" ]; then
  echo "note: $SKILLS_DST is a symlink (whole-directory mode) — nothing to link."
  echo "      New skills already appear automatically after 'git pull'."
  exit 0
fi

mkdir -p "$SKILLS_DST"


linked=0 updated=0 skipped=0 warned=0

for skill_path in "$SKILLS_SRC"/*/; do
  [ -d "$skill_path" ] || continue          # skip non-directories
  skill_path="${skill_path%/}"              # strip trailing slash
  name="$(basename "$skill_path")"
  target="$SKILLS_DST/$name"

  # Warn if a SKILL.md is missing (likely not a valid skill)
  if [ ! -f "$skill_path/SKILL.md" ]; then
    echo "warn:    $name has no SKILL.md — linking anyway"
  fi

  if [ -L "$target" ]; then
    current="$(readlink "$target")"
    if [ "$current" = "$skill_path" ]; then
      skipped=$((skipped + 1))              # already correct
    else
      ln -sfn "$skill_path" "$target"       # repoint stale link
      echo "updated: $name"
      updated=$((updated + 1))
    fi
  elif [ -e "$target" ]; then
    echo "WARNING: $target exists and is NOT a symlink — leaving untouched" >&2
    warned=$((warned + 1))
  else
    ln -s "$skill_path" "$target"           # create new link
    echo "linked:  $name"
    linked=$((linked + 1))
  fi
done

# Prune dangling symlinks that point into this repo but whose source is gone
for link in "$SKILLS_DST"/*; do
  [ -L "$link" ] || continue
  dest="$(readlink "$link")"
  case "$dest" in
    "$SKILLS_SRC"/*)
      if [ ! -e "$dest" ]; then
        rm "$link"
        echo "pruned:  $(basename "$link") (source removed)"
      fi
      ;;
  esac
done


# Install the git hook so this runs automatically after every `git pull`.
# Uses core.hooksPath (local to this repo only) — does not touch global config.
if [ -d "$REPO_DIR/.git" ] || git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  if [ -d "$REPO_DIR/.githooks" ]; then
    current_hookspath="$(git -C "$REPO_DIR" config --local core.hooksPath || true)"
    if [ "$current_hookspath" != ".githooks" ]; then
      git -C "$REPO_DIR" config --local core.hooksPath .githooks
      echo "hook:    installed post-merge hook (core.hooksPath=.githooks)"
    fi
  fi
fi

echo ""
echo "Done. linked=$linked updated=$updated already-ok=$skipped warnings=$warned"
echo "Skills dir: $SKILLS_DST"
echo "Restart Kiro (or start a new session) for changes to take effect."

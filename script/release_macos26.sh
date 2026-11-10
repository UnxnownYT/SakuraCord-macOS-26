#!/usr/bin/env bash
# Builds an update-enabled DMG, signs its Sparkle feed and publishes the feed
# to the fork's `updates` branch.
#   ./script/release_macos26.sh nightly v0.1.7-Beta-6 notes.md
#   ./script/release_macos26.sh stable  v0.1.7        notes.md
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=release_metadata.sh
source "$ROOT_DIR/script/release_metadata.sh"

CHANNEL="${1:-}"; TAG="${2:-}"; NOTES="${3:-}"
PUBLIC_KEY="4rcAMtD8xUm3jNKoEYd74xnhwLhYRtk4X8Ys+mF7BXo="
KEY_FILE="${SAKURACORD_SPARKLE_KEY_FILE:-$HOME/SakuraCord-sparkle-private-key.txt}"
REMOTE="${SAKURACORD_FORK_REMOTE:-fork}"
REPO_URL="https://github.com/UnxnownYT/SakuraCord-macOS-26"

usage() { echo "Usage: $0 stable|nightly vX.Y.Z[-Beta-N] release-notes.md" >&2; exit 2; }
[[ -n "$CHANNEL" && -n "$TAG" && -n "$NOTES" ]] || usage
sakuracord_is_release_tag "$TAG" || { echo "Tag must look like v0.1.7 or v0.1.7-Beta-6." >&2; exit 2; }
case "$CHANNEL" in
  stable)
    TRACK=regular; FEED=stable.xml; BRANCH=macos26-port
    ! sakuracord_is_nightly_release_tag "$TAG" || { echo "Stable releases need a tag without -Beta-N." >&2; exit 2; } ;;
  nightly)
    TRACK=nightly; FEED=nightly.xml; BRANCH=macos26-nightly
    sakuracord_is_nightly_release_tag "$TAG" || { echo "Nightly releases need a -Beta-N tag." >&2; exit 2; } ;;
  *) usage ;;
esac
[[ -s "$NOTES" ]] || { echo "Release notes file is missing or empty: $NOTES" >&2; exit 1; }
[[ "$NOTES" = /* ]] || NOTES="$PWD/$NOTES"
[[ -s "$KEY_FILE" ]] || { echo "Private key not found at $KEY_FILE" >&2; exit 1; }

cd "$ROOT_DIR"
CURRENT="$(git branch --show-current)"
if [[ "$CURRENT" != "$BRANCH" ]]; then
  echo "You're on '$CURRENT', but $CHANNEL releases are built from '$BRANCH'." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo "Commit your changes before releasing." >&2
  exit 1
fi

export SAKURACORD_ENABLE_UPDATES=1
export SAKURACORD_RELEASE_TRACK="$TRACK"
export SAKURACORD_RELEASE_TAG="$TAG"
export SAKURACORD_VERSION="$(sakuracord_release_version_from_tag "$TAG")"
export SAKURACORD_BUILD_NUMBER="${SAKURACORD_BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
export SPARKLE_ED_PUBLIC_KEY="$PUBLIC_KEY"
export SAKURACORD_CODE_SIGN_IDENTITY="${SAKURACORD_CODE_SIGN_IDENTITY:--}"
export DMGBUILD="${DMGBUILD:-$(python3 -m site --user-base)/bin/dmgbuild}"

DMG_NAME="$(sakuracord_release_dmg_name_from_tag "$TAG")"
DMG_URL_NAME="$DMG_NAME"
if [[ "${SAKURACORD_SKIP_BUILD:-0}" == "1" && -f "dist/$DMG_NAME" ]]; then
  echo "==> Reusing dist/$DMG_NAME"
else
  rm -f "dist/$DMG_NAME"
  echo "==> Building $DMG_NAME ($CHANNEL, $TAG). This takes a while."
  # package_dmg.sh can fail to remove its read-only scratch copy after the
  # DMG is made; only a missing DMG counts as a failed build.
  "$ROOT_DIR/script/package_dmg.sh" </dev/null || true
  [[ -f "dist/$DMG_NAME" ]] || { echo "The DMG was not created; see the errors above." >&2; exit 1; }
fi

rm -f "dist/$FEED"
echo "==> Signing the $CHANNEL feed"
SPARKLE_ED_PRIVATE_KEY="$(cat "$KEY_FILE")" \
  "$ROOT_DIR/script/generate_appcast.sh" "dist/$DMG_NAME" "dist/$FEED" "$NOTES"

cat <<MSG

==> Almost done. Before the feed goes live:
    1. Open $REPO_URL/releases/new
    2. Tag: $TAG   Target: $BRANCH   $( [[ $CHANNEL == nightly ]] && echo "(tick 'Set as a pre-release')" )
    3. Upload: dist/$DMG_NAME   (keep the file name exactly as it is)
    4. Publish the release.

MSG
read -r -p "Press Enter once the release is published (Ctrl+C to stop here)... " </dev/tty

if ! curl -fsIL "$REPO_URL/releases/download/$TAG/$DMG_URL_NAME" >/dev/null; then
  echo "Can't find $REPO_URL/releases/download/$TAG/$DMG_URL_NAME yet." >&2
  echo "Check the release, then run this script again." >&2
  exit 1
fi

echo "==> Publishing dist/$FEED to the updates branch"
WORKTREE="$(mktemp -d)/updates"
if git ls-remote --exit-code --heads "$REMOTE" updates >/dev/null 2>&1; then
  git fetch -q "$REMOTE" updates
  git worktree add -q -B updates "$WORKTREE" "$REMOTE/updates"
else
  git worktree add -q --detach "$WORKTREE"
  git -C "$WORKTREE" checkout -q --orphan updates
  git -C "$WORKTREE" rm -rq . || true
  printf '# SakuraCord for macOS 26 update feeds\n\nstable.xml and nightly.xml are read by the app. Do not edit by hand.\n' > "$WORKTREE/README.md"
fi
cp "dist/$FEED" "$WORKTREE/$FEED"
git -C "$WORKTREE" add -A
git -C "$WORKTREE" commit -qm "$CHANNEL: $TAG"
git -C "$WORKTREE" push -q "$REMOTE" updates
git worktree remove --force "$WORKTREE"

echo "==> Done. $CHANNEL users will be offered $TAG within six hours, or straight away via Check for Updates."

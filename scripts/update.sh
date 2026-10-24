#!/bin/sh
# Rebuild CustomKIMI on top of an official Kimi Code release.
#
#   sh scripts/update.sh              update to the latest release (no-op when already on it)
#   sh scripts/update.sh 2.3.0        build a specific release (always rebuilds)
#   sh scripts/update.sh --check      show the installed and latest versions
#   sh scripts/update.sh --continue   finish an update after resolving patch conflicts in source.next
#   sh scripts/update.sh --rollback   swap back to the previous build (run again to swap forward)
#   sh scripts/update.sh --save       save the changes committed in source/ into custom/patches
#
# The release is cloned into source.next and custom/patches are applied on
# top. It is installed, typechecked, the custom feature tests run, and it is
# built. Only when all of that passes does source.next replace source (the
# old build is kept as source.previous) and `kimi` get re-linked. Any failure
# leaves the current build untouched. An update refuses to start while
# source/ or source.previous/ holds changes that --save has not stored yet.
set -eu

repo_url=https://github.com/MoonshotAI/kimi-code.git
package=@moonshot-ai/kimi-code
bundle_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
source_root="$bundle_root/source"
next_root="$bundle_root/source.next"
previous_root="$bundle_root/source.previous"
patches_dir="$bundle_root/custom/patches"
history_dir="$bundle_root/custom/history"
base_file="$bundle_root/custom/BASE_VERSION"

say() { printf '%s\n' "$*"; }
die() {
  printf 'update: %s\n' "$*" >&2
  exit 1
}

version_of() {
  node -p 'require(process.argv[1]).version' "$1/apps/kimi-code/package.json" 2>/dev/null || true
}

latest_version() {
  curl -fsS --max-time 30 'https://registry.npmjs.org/@moonshot-ai%2fkimi-code/latest' |
    node -e 'let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () => console.log(JSON.parse(s).version))'
}

relink() {
  # The package's postinstall only migrates a legacy Python `kimi`; a source link does not need it.
  (cd "$source_root/apps/kimi-code" && npm link --ignore-scripts >/dev/null) || die 'npm link failed'
}

verify_active() {
  kimi_bin=$(command -v kimi || true)
  [ -n "$kimi_bin" ] || die "kimi is not on PATH; add $(npm prefix -g)/bin to PATH"
  case $(realpath "$kimi_bin") in
    "$source_root"/*) ;;
    *) die "kimi resolves to $(realpath "$kimi_bin") instead of $source_root" ;;
  esac
  active=$(KIMI_CODE_NO_AUTO_UPDATE=1 "$kimi_bin" --version)
  [ "$active" = "$1" ] || die "kimi --version printed '$active', expected '$1'"
  say "kimi $active is active."
  install_launcher "$kimi_bin"
}

# Optional per-machine launcher (scripts/kimi-launcher.sh): a script that puts
# API keys from the OS keychain into the environment and then runs the linked
# build. `npm link` always recreates `kimi` as a bare symlink, so put the
# launcher back on top of it. Nothing happens when the file does not exist.
install_launcher() {
  launcher="$bundle_root/scripts/kimi-launcher.sh"
  [ -f "$launcher" ] || return 0
  rm -f "$1" && cp "$launcher" "$1" && chmod +x "$1" || die "could not install $launcher as $1"
  say "Reinstalled the Keychain launcher as $1."
}

# True when a build has uncommitted edits, or commits made after the last save.
unsaved_changes() {
  [ -d "$1/.git" ] || return 1
  [ -z "$(git -C "$1" status --porcelain)" ] || return 0
  saved=$(git -C "$1" rev-parse --quiet --verify refs/customkimi/saved || true)
  [ -n "$saved" ] && [ "$saved" != "$(git -C "$1" rev-parse HEAD)" ]
}

refuse_unsaved() {
  for build in "$source_root" "$previous_root"; do
    if unsaved_changes "$build"; then
      git -C "$build" status --short | sed 's/^/  /' >&2
      git -C "$build" log --oneline refs/customkimi/saved..HEAD 2>/dev/null | sed 's/^/  unsaved commit: /' >&2
      die "$(basename "$build")/ has changes that are not saved in custom/patches, and this update would replace them.
Commit them in $(basename "$build")/ and run: sh scripts/update.sh --save"
    fi
  done
}

mode=update
target=
case ${1:-} in
  --check) mode=check ;;
  --continue) mode=continue ;;
  --rollback) mode=rollback ;;
  --save) mode=save ;;
  -h | --help)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  -*) die "unknown option: $1 (see --help)" ;;
  *) target=${1:-} ;;
esac

command -v node >/dev/null 2>&1 || die 'Node.js 24.15 or newer is required.'
installed=
[ -d "$source_root" ] && installed=$(version_of "$source_root")

if [ "$mode" = check ]; then
  latest=$(latest_version) || die 'could not reach the npm registry'
  say "installed: ${installed:-none}"
  say "latest:    $latest"
  if [ "$installed" = "$latest" ]; then say 'CustomKIMI is up to date.'; else say 'Run: sh scripts/update.sh'; fi
  exit 0
fi

if [ "$mode" = rollback ]; then
  [ -d "$previous_root" ] || die 'there is no previous build to roll back to'
  swap_root="$bundle_root/source.swap"
  [ ! -e "$swap_root" ] || die "$swap_root exists from an interrupted rollback; move it back to source or source.previous first"
  previous=$(version_of "$previous_root")
  mv "$source_root" "$swap_root"
  mv "$previous_root" "$source_root"
  mv "$swap_root" "$previous_root"
  relink
  verify_active "$previous"
  say "Switched from $installed to $previous. Run --rollback again to switch back."
  exit 0
fi

if [ "$mode" = save ]; then
  [ -d "$source_root/.git" ] || die "there is no source/ build to save from"
  if [ -n "$(git -C "$source_root" status --porcelain)" ]; then
    git -C "$source_root" status --short | sed 's/^/  /' >&2
    die "commit these changes first: cd source && git add -A && git commit -m '<what you changed>'"
  fi
  base=$(cat "$base_file" 2>/dev/null || true)
  [ "$installed" = "$base" ] ||
    die "source/ is Kimi Code $installed but custom/patches are for ${base:-unknown}; switch back with --rollback first"
  tag="$package@$installed"
  count=$(git -C "$source_root" rev-list --count "$tag..HEAD")
  [ "$count" -gt 0 ] || die "source/ has no commits on top of $tag; nothing to save"
  backup="$history_dir/$installed-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup"
  mv "$patches_dir"/*.patch "$backup/"
  git -C "$source_root" format-patch --quiet --full-index -o "$patches_dir" "$tag..HEAD"
  git -C "$source_root" update-ref refs/customkimi/saved HEAD
  say "Saved $count patches to custom/patches (the previous set is in custom/history/$(basename "$backup"))."
  say 'Describe new or changed features in custom/FEATURES.md.'
  exit 0
fi

node_version=$(node --version | tr -d v)
node -e 'const [major, minor] = process.argv[1].split(".").map(Number); process.exit(major > 24 || (major === 24 && minor >= 15) ? 0 : 1)' "$node_version" ||
  die "Node.js 24.15 or newer is required; found $node_version"
for tool in corepack git curl npm; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is required"
done

if [ "$mode" = continue ]; then
  [ -d "$next_root" ] || die "nothing to continue: $next_root does not exist"
  refuse_unsaved
  [ ! -d "$next_root/.git/rebase-apply" ] ||
    die "a patch is still being applied in source.next; resolve it, run 'git add' and 'git am --continue' there first"
  target=$(version_of "$next_root")
  tag="$package@$target"
else
  if [ -z "$target" ]; then
    target=$(latest_version) || die 'could not reach the npm registry'
    if [ "$target" = "$installed" ]; then
      say "CustomKIMI is already on the latest Kimi Code ($installed)."
      exit 0
    fi
  fi
  refuse_unsaved
  tag="$package@$target"
  say "Building CustomKIMI on Kimi Code $target (installed: ${installed:-none})."
  rm -rf "$next_root"
  # Borrow the objects the current build already has, so only what changed
  # since it is downloaded. --dissociate copies them, so source.next never
  # depends on source/, which a later update deletes as source.previous.
  set --
  [ ! -d "$source_root/.git" ] || set -- --reference-if-able "$source_root" --dissociate
  git clone --filter=blob:none --no-checkout "$@" "$repo_url" "$next_root" ||
    die "could not download Kimi Code from $repo_url"
  git -C "$next_root" rev-parse --quiet --verify "refs/tags/$tag" >/dev/null ||
    die "Kimi Code $target has no release tag ($tag)"
  git -C "$next_root" switch --quiet -c "customkimi-$target" "$tag"
  # When upstream changed the lines around a patch, `git am --3way` merges it
  # using the file versions the patch was saved against. Those exist nowhere
  # upstream, so recreate them first by applying the patches, index only, to
  # the release they were saved for. Without them such a patch stops with
  # "could not fetch ... from promisor remote" and no conflict markers.
  saved_base=$(cat "$base_file" 2>/dev/null || true)
  if [ -n "$saved_base" ] && [ "$saved_base" != "$target" ]; then
    replay_index="$next_root/.git/customkimi-replay-index"
    if ! (
      export GIT_INDEX_FILE="$replay_index"
      git -C "$next_root" read-tree "$package@$saved_base" || exit 1
      for patch in "$patches_dir"/*.patch; do
        git -C "$next_root" apply --cached "$patch" || exit 1
      done
    ); then
      say "warning: the patches could not be replayed on $saved_base; a patch that needs merging will stop without conflict markers"
    fi
    rm -f "$replay_index"
  fi
  say 'Applying custom patches:'
  for patch in "$patches_dir"/*.patch; do say "  $(basename "$patch")"; done
  if ! git -C "$next_root" -c user.name=CustomKIMI -c user.email=customkimi@localhost \
    am --quiet --3way "$patches_dir"/*.patch; then
    failed=$(sed -n 1p "$next_root/.git/rebase-apply/final-commit" 2>/dev/null || true)
    cat >&2 <<EOF

update: a custom patch no longer applies cleanly to Kimi Code $target.
  failing patch: ${failed:-unknown}
  conflicted files:
$(git -C "$next_root" diff --name-only --diff-filter=U | sed 's/^/    /')

Your current kimi is unchanged. To finish the update:
  1. Resolve the conflicts in $next_root so the feature still works as
     described in custom/FEATURES.md (an AI agent can do this from that file).
  2. cd "$next_root" && git add <files> && git am --continue
     (repeat if a later patch conflicts too)
  3. sh scripts/update.sh --continue
EOF
    exit 1
  fi
fi

cd "$next_root"
say 'Installing dependencies...'
corepack pnpm install --frozen-lockfile
say 'Building workspace packages...'
corepack pnpm run build:packages

changed=$(git diff --name-only "$tag" HEAD)
packages=$(printf '%s\n' "$changed" | awk -F/ '($1 == "apps" || $1 == "packages") && NF > 2 { print $1 "/" $2 }' | sort -u)
# The tests get a throwaway Kimi home and no network beyond this Mac (every
# request outside localhost goes to a proxy that refuses it). Some of
# upstream's tests otherwise read and write your ~/.kimi-code, and live
# settings from Kimi's servers (or cached from them in ~/.kimi-code, such as
# the survey popup's model list) make them fail outside upstream's CI.
test_home=$(mktemp -d "${TMPDIR:-/tmp}/customkimi-tests.XXXXXX")
trap 'rm -rf "$test_home"' EXIT
no_network='NODE_USE_ENV_PROXY=1 HTTP_PROXY=http://127.0.0.1:9 HTTPS_PROXY=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 NO_PROXY=localhost,127.0.0.1,::1 no_proxy=localhost,127.0.0.1,::1'
for pkg in $packages; do
  if node -e 'process.exit(require(process.argv[1]).scripts?.typecheck ? 0 : 1)' "$next_root/$pkg/package.json"; then
    say "Typechecking $pkg..."
    corepack pnpm -C "$pkg" run typecheck
  fi
  tests=$(printf '%s\n' "$changed" | grep "^$pkg/" | grep -E '\.test\.[cm]?[jt]sx?$' | sed "s|^$pkg/||" || true)
  if [ -n "$tests" ]; then
    say "Testing custom features in $pkg..."
    pkg_home="$test_home/$(basename "$pkg")"
    mkdir -p "$pkg_home"
    # shellcheck disable=SC2086 # one argument per variable and per test file
    env KIMI_CODE_HOME="$pkg_home" $no_network corepack pnpm -C "$pkg" exec vitest run $tests
  fi
done

say 'Building kimi...'
corepack pnpm --filter "$package" run build
built=$(KIMI_CODE_NO_AUTO_UPDATE=1 node apps/kimi-code/dist/main.mjs --version)
[ "$built" = "$target" ] || die "the new build reports version $built, expected $target"

cd "$bundle_root"
rm -rf "$previous_root"
[ ! -d "$source_root" ] || mv "$source_root" "$previous_root"
mv "$next_root" "$source_root"
relink
verify_active "$target"

old_base=$(cat "$base_file" 2>/dev/null || printf 'unknown')
if [ "$old_base" != "$target" ]; then
  mkdir -p "$history_dir/$old_base"
  mv "$patches_dir"/*.patch "$history_dir/$old_base/"
fi
rm -f "$patches_dir"/*.patch
git -C "$source_root" format-patch --quiet --full-index -o "$patches_dir" "$tag..HEAD"
git -C "$source_root" update-ref refs/customkimi/saved HEAD
printf '%s\n' "$target" >"$base_file"

say ''
say "CustomKIMI is now on Kimi Code $target. Patches in custom/patches were refreshed against it."
[ ! -d "$previous_root" ] || say "The previous build is kept in source.previous; undo with: sh scripts/update.sh --rollback"
say 'Restart any open Kimi sessions to use the new version.'

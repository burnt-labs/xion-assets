#!/usr/bin/env bash
# Update the Xion chain-registry files for a release.
#
#   scripts/update-chain-registry.sh <mainnet|testnet> <tag>
#
# Rewrites <registry-dir>/chain.json and <registry-dir>/versions.json with the
# release's binaries, checksums, dependency versions (from the release's
# go.mod), and — when a matching upgrade proposal exists in the network's
# governance repo — the upgrade height and proposal number.
#
# Requires: curl, jq, go, git.
#
# Environment:
#   PROPOSALS_DIR  Optional path to an existing checkout of the network's
#                  governance repo (xion-mainnet-1 / xion-testnet-2). When
#                  unset, the repo is shallow-cloned into a temp directory.
#   GITHUB_OUTPUT  When set (as in GitHub Actions), the extracted values are
#                  appended to it as step outputs.
set -Eeuo pipefail

usage() { echo "usage: $0 <mainnet|testnet> <tag>" >&2; exit 2; }

NETWORK="${1:-}"
TAG_NAME="${2:-}"
[ -n "$NETWORK" ] && [ -n "$TAG_NAME" ] || usage

case "$NETWORK" in
  mainnet)
    REGISTRY_DIR="public/chain-registry/xion"
    PROPOSALS_REPO="burnt-labs/xion-mainnet-1"
    ;;
  testnet)
    REGISTRY_DIR="public/chain-registry/testnets/xiontestnet2"
    PROPOSALS_REPO="burnt-labs/xion-testnet-2"
    ;;
  *) usage ;;
esac

VERSION="${TAG_NAME#v}"
# Major version names the upgrade (e.g. v21.0.1 -> v21).
MAJOR_VERSION=$(echo "$TAG_NAME" | sed -E 's/^v([0-9]+)\..*/v\1/')

for cmd in curl jq go git; do
  command -v "$cmd" >/dev/null || { echo "error: $cmd is required" >&2; exit 1; }
done
[ -d "$REGISTRY_DIR" ] || { echo "error: $REGISTRY_DIR not found — run from the repo root" >&2; exit 1; }

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# The two registry dirs are indented differently (2 vs 4 spaces); rewrite each
# file with its own indentation so diffs stay reviewable.
file_indent() {
  local n
  n=$(sed -n '2s/^\( *\).*/\1/p' "$1" | wc -c)
  echo $(( n > 1 ? n - 1 : 2 ))
}

# jq flags that rewrite a file in its own style: its indentation, and ASCII
# output (-a) when the file is pure ASCII, i.e. keeps non-ASCII characters
# such as the provider emoji as \u escapes (testnet chain.json does).
jq_style() {
  local flags=(--indent "$(file_indent "$1")")
  LC_ALL=C grep -q '[^[:print:][:space:]]' "$1" || flags+=(-a)
  printf '%s\n' "${flags[@]}"
}
mapfile -t JQ_FLAGS_CHAIN < <(jq_style "$REGISTRY_DIR/chain.json")
mapfile -t JQ_FLAGS_VERSIONS < <(jq_style "$REGISTRY_DIR/versions.json")

# --- Checksums for the release binaries -------------------------------------
echo "Downloading checksums for ${TAG_NAME}..."
curl -fsSL -o "$WORKDIR/checksums.txt" \
  "https://github.com/burnt-labs/xion/releases/download/${TAG_NAME}/xiond-${VERSION}-checksums.txt"

checksum() {
  # Exact filename match (so .sbom.json entries can't hit) in a single awk call:
  # a pipeline here would trip pipefail on a missing entry before the per-platform
  # "not found" checks below get to report which one.
  awk -v want="xiond_${VERSION}_$1.tar.gz" '$2 == want { print $1 }' "$WORKDIR/checksums.txt"
}
DARWIN_AMD64=$(checksum darwin_amd64)
DARWIN_ARM64=$(checksum darwin_arm64)
LINUX_AMD64=$(checksum linux_amd64)
LINUX_ARM64=$(checksum linux_arm64)
for v in DARWIN_AMD64 DARWIN_ARM64 LINUX_AMD64 LINUX_ARM64; do
  [ -n "${!v}" ] || { echo "error: ${v,,} checksum not found for ${VERSION}" >&2; exit 1; }
done

# --- Dependency versions from the release's go.mod ---------------------------
curl -fsSL -o "$WORKDIR/go.mod" \
  "https://raw.githubusercontent.com/burnt-labs/xion/${TAG_NAME}/go.mod"

gomod() { (cd "$WORKDIR" && go mod edit -json) | jq -c "$1"; }

# dep(select) -> the registry object for one dependency: {version} for a plain
# upstream release, or {version, repo, tag} when the build uses something else.
# The chain-registry schema only allows a simple version (^v?\d+(\.\d+){0,2}$),
# so the exact module version goes in "tag":
#   - a replace directive (our forks, e.g. burnt-labs/wasmd v0.70.5-xion.4):
#     version v0.70.5, repo = the fork, tag = the fork's tag;
#   - a pseudo-version (an untagged commit, e.g. v11.0.0-20261019144822-2757a8778d05):
#     version = the major line (v11), tag = the pseudo-version;
#   - a pre-release (v0.55.0-rc.1): version v0.55.0, tag = the pre-release.
# The go.mod require line alone is wrong whenever a replace directive applies.
# shellcheck disable=SC2016 # jq program, not shell expansions
DEP_JQ='
def dep(sel):
  (first(.Require[]? | select(.Path | sel)) // null) as $req
  | if $req == null then null else
      (first(.Replace[]? | select(.Old.Path == $req.Path and (.Old.Version == null or .Old.Version == $req.Version))) // null) as $rep
      | if $rep != null and $rep.New.Version == null then error("\($req.Path) is replaced by a local path") else . end
      | ($rep.New.Path // $req.Path) as $path
      | ($rep.New.Version // $req.Version) as $ver
      | ("https://" + ($path | sub("/v[0-9]+$"; ""))) as $repo
      | ($ver | capture("^(?<core>v[0-9]+\\.[0-9]+\\.[0-9]+)(?<rest>.*)$")) as $m
      | if ($ver | test("[0-9]{14}-[0-9a-f]{12}$")) then
          {version: ($ver | capture("^(?<major>v[0-9]+)").major), repo: $repo, tag: $ver}
        elif $rep != null or $m.rest != "" then
          {version: $m.core, repo: $repo, tag: $ver}
        else
          {version: $ver}
        end
    end;
'
SDK_DEP=$(gomod "$DEP_JQ"'dep(. == "github.com/cosmos/cosmos-sdk")')
COMETBFT_DEP=$(gomod "$DEP_JQ"'dep(. == "github.com/cometbft/cometbft")')
WASMD_DEP=$(gomod "$DEP_JQ"'dep(. == "github.com/CosmWasm/wasmd")')
IBC_DEP=$(gomod "$DEP_JQ"'dep(startswith("github.com/cosmos/ibc-go/v") and (contains("light-clients") | not) and (contains("capability") | not) and (contains("middleware") | not))')
GO_VERSION="v$(gomod '.Go' | jq -r .)"

# Registry files must never carry empty/placeholder versions — fail loudly instead.
for v in SDK_DEP COMETBFT_DEP WASMD_DEP IBC_DEP; do
  [ -n "${!v}" ] && [ "${!v}" != null ] || { echo "error: could not extract ${v} from ${TAG_NAME}'s go.mod" >&2; exit 1; }
done

# One line per dependency for logs and the PR body: the exact module version,
# plus the repo when it isn't a plain upstream release.
dep_detail() { jq -r 'if .tag then "\(.tag) (\(.repo | ltrimstr("https://")))" else .version end' <<<"$1"; }
SDK_VERSION=$(dep_detail "$SDK_DEP")
COMETBFT_VERSION=$(dep_detail "$COMETBFT_DEP")
WASMD_VERSION=$(dep_detail "$WASMD_DEP")
IBC_VERSION=$(dep_detail "$IBC_DEP")

echo "Extracted versions:"
echo "  SDK: ${SDK_VERSION}"
echo "  CometBFT: ${COMETBFT_VERSION}"
echo "  CosmWasm: ${WASMD_VERSION}"
echo "  IBC: ${IBC_VERSION}"
echo "  Go: ${GO_VERSION}"

# --- Upgrade height + proposal number from the governance repo ---------------
if [ -z "${PROPOSALS_DIR:-}" ]; then
  git clone --depth 1 "https://github.com/${PROPOSALS_REPO}.git" "$WORKDIR/proposals-repo" >/dev/null
  PROPOSALS_DIR="$WORKDIR/proposals-repo"
fi

HEIGHT=0
PROPOSAL=0
PROPOSAL_FOUND=false
PROPOSAL_FILE=""
for f in "$PROPOSALS_DIR"/proposals/[0-9]*-upgrade-"${MAJOR_VERSION}".json; do
  [ -e "$f" ] || continue
  PROPOSAL_FILE=$(basename "$f")
  break
done
if [ -z "$PROPOSAL_FILE" ]; then
  echo "⚠️  No proposal file found for ${MAJOR_VERSION} in ${PROPOSALS_REPO}"
else
  echo "Found proposal file: ${PROPOSAL_FILE}"
  PROPOSAL=$(echo "$PROPOSAL_FILE" | sed -E 's/^0*([0-9]+)-.*/\1/')
  HEIGHT=$(jq -r '.messages[0].plan.height // empty' "$PROPOSALS_DIR/proposals/$PROPOSAL_FILE")
  if ! [[ "$HEIGHT" =~ ^[0-9]+$ ]]; then
    echo "error: invalid upgrade height '${HEIGHT}' in ${PROPOSAL_FILE}" >&2
    exit 1
  fi
  PROPOSAL_FOUND=true
  echo "  Proposal: ${PROPOSAL}"
  echo "  Height: ${HEIGHT}"
fi

# --- Rewrite chain.json ------------------------------------------------------
binary_url() {
  echo "https://github.com/burnt-labs/xion/releases/download/${TAG_NAME}/xiond_${VERSION}_$1.tar.gz?checksum=sha256:$2"
}
BINARIES=$(jq -n \
  --arg darwin_amd64 "$(binary_url darwin_amd64 "$DARWIN_AMD64")" \
  --arg darwin_arm64 "$(binary_url darwin_arm64 "$DARWIN_ARM64")" \
  --arg linux_amd64 "$(binary_url linux_amd64 "$LINUX_AMD64")" \
  --arg linux_arm64 "$(binary_url linux_arm64 "$LINUX_ARM64")" \
  '{"darwin/amd64": $darwin_amd64, "darwin/arm64": $darwin_arm64,
    "linux/amd64": $linux_amd64, "linux/arm64": $linux_arm64}')

# codebase.compatible_versions follows this major's versions.json entry (computed
# the same way the versions.json rewrite below does): just this tag for a new
# major, plus the earlier compatible versions for a patch release.
COMPATIBLE=$(jq -c --arg name "$MAJOR_VERSION" --arg tag "$TAG_NAME" \
  '(first(.versions[] | select(.name == $name)).compatible_versions // []) + [$tag] | unique' \
  "$REGISTRY_DIR/versions.json")

# Each dependency object is replaced as a whole (version, repo, tag), so a fork
# or pseudo-version recorded for an earlier release can't linger; other keys
# (type, enabled, ics_enabled, path) are kept.
jq "${JQ_FLAGS_CHAIN[@]}" \
   --arg tag "$TAG_NAME" \
   --argjson compatible "$COMPATIBLE" \
   --arg go_version "$GO_VERSION" \
   --argjson sdk "$SDK_DEP" \
   --argjson cometbft "$COMETBFT_DEP" \
   --argjson wasmd "$WASMD_DEP" \
   --argjson ibc "$IBC_DEP" \
   --argjson binaries "$BINARIES" \
   'def setdep($k; $dep; $type):
      (.codebase[$k] // {}) as $old
      | .codebase[$k] = ((if $type == null then {} else {type: ($old.type // $type)} end)
                         + $dep + ($old | del(.type, .version, .repo, .tag)));
    .codebase.tag = $tag |
    .codebase.recommended_version = $tag |
    .codebase.compatible_versions = $compatible |
    .codebase.language.version = $go_version |
    .codebase.binaries = $binaries |
    setdep("sdk"; $sdk; "cosmos") |
    setdep("consensus"; $cometbft; "cometbft") |
    setdep("cosmwasm"; $wasmd; null) |
    setdep("ibc"; $ibc; "go")' \
   "$REGISTRY_DIR/chain.json" > "$WORKDIR/chain.json"
mv "$WORKDIR/chain.json" "$REGISTRY_DIR/chain.json"
echo "Updated $REGISTRY_DIR/chain.json"

# --- Rewrite versions.json ---------------------------------------------------
# A new major gets a fresh entry with the proposal's height/number; a patch to
# an existing major keeps the recorded height/proposal (backfilling them when
# still 0, i.e. the proposal did not exist at first publish) and extends
# compatible_versions.
ENTRY=$(jq -n \
  --arg name "$MAJOR_VERSION" \
  --arg tag "$TAG_NAME" \
  --arg go_version "$GO_VERSION" \
  --argjson sdk "$SDK_DEP" \
  --argjson cometbft "$COMETBFT_DEP" \
  --argjson wasmd "$WASMD_DEP" \
  --argjson ibc "$IBC_DEP" \
  --argjson binaries "$BINARIES" \
  --argjson height "$HEIGHT" \
  --argjson proposal "$PROPOSAL" \
  '{name: $name, tag: $tag, recommended_version: $tag,
    compatible_versions: [$tag], height: $height, proposal: $proposal,
    language: {type: "go", version: $go_version},
    binaries: $binaries,
    sdk: ({type: "cosmos"} + $sdk),
    consensus: ({type: "cometbft"} + $cometbft),
    cosmwasm: ($wasmd + {enabled: true}),
    ibc: ({type: "go"} + $ibc)}')

jq "${JQ_FLAGS_VERSIONS[@]}" \
   --arg name "$MAJOR_VERSION" \
   --argjson entry "$ENTRY" \
   'if (.versions | any(.name == $name)) then
      (.versions[] | select(.name == $name)) |=
        (. as $old | $entry
         + {height: (if ($old.height // 0) == 0 then $entry.height else $old.height end),
            proposal: (if ($old.proposal // 0) == 0 then $entry.proposal else $old.proposal end),
            compatible_versions: (($old.compatible_versions + $entry.compatible_versions) | unique)})
    else
      .versions += [$entry]
    end' \
   "$REGISTRY_DIR/versions.json" > "$WORKDIR/versions.json"
mv "$WORKDIR/versions.json" "$REGISTRY_DIR/versions.json"
echo "Updated $REGISTRY_DIR/versions.json"

# --- Step outputs for the workflow -------------------------------------------
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "tag_name=${TAG_NAME}"
    echo "version=${VERSION}"
    echo "major_version=${MAJOR_VERSION}"
    echo "registry_dir=${REGISTRY_DIR}"
    echo "darwin_amd64=${DARWIN_AMD64}"
    echo "darwin_arm64=${DARWIN_ARM64}"
    echo "linux_amd64=${LINUX_AMD64}"
    echo "linux_arm64=${LINUX_ARM64}"
    echo "sdk_version=${SDK_VERSION}"
    echo "cometbft_version=${COMETBFT_VERSION}"
    echo "wasmd_version=${WASMD_VERSION}"
    echo "ibc_version=${IBC_VERSION}"
    echo "go_version=${GO_VERSION}"
    echo "proposal_found=${PROPOSAL_FOUND}"
    echo "proposal=${PROPOSAL}"
    echo "height=${HEIGHT}"
  } >> "$GITHUB_OUTPUT"
fi

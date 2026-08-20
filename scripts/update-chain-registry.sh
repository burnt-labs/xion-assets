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

# --- Checksums for the release binaries -------------------------------------
echo "Downloading checksums for ${TAG_NAME}..."
curl -fsSL -o "$WORKDIR/checksums.txt" \
  "https://github.com/burnt-labs/xion/releases/download/${TAG_NAME}/xiond-${VERSION}-checksums.txt"

checksum() {
  # Anchor with $ to avoid matching .sbom.json entries.
  grep "xiond_${VERSION}_$1\.tar\.gz\$" "$WORKDIR/checksums.txt" | awk '{print $1}'
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

gomod() { (cd "$WORKDIR" && go mod edit -json) | jq -r "$1"; }
SDK_VERSION=$(gomod '.Require[] | select(.Path == "github.com/cosmos/cosmos-sdk") | .Version')
COMETBFT_VERSION=$(gomod '.Require[] | select(.Path == "github.com/cometbft/cometbft") | .Version')
WASMD_VERSION=$(gomod '.Require[] | select(.Path == "github.com/CosmWasm/wasmd") | .Version // empty')
IBC_VERSION=$(gomod '.Require[] | select(.Path | startswith("github.com/cosmos/ibc-go/v")) | select(.Path | contains("light-clients") | not) | select(.Path | contains("capability") | not) | select(.Path | contains("middleware") | not) | .Version' | head -1)
GO_VERSION="v$(gomod '.Go')"

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
PROPOSAL_FILE=$(ls -1 "$PROPOSALS_DIR/proposals" | grep -E "^[0-9]+-upgrade-${MAJOR_VERSION}\.json$" | head -1 || true)
if [ -z "$PROPOSAL_FILE" ]; then
  echo "⚠️  No proposal file found for ${MAJOR_VERSION} in ${PROPOSALS_REPO}"
else
  echo "Found proposal file: ${PROPOSAL_FILE}"
  PROPOSAL=$(echo "$PROPOSAL_FILE" | sed -E 's/^0*([0-9]+)-.*/\1/')
  HEIGHT=$(jq -r '.messages[0].plan.height' "$PROPOSALS_DIR/proposals/$PROPOSAL_FILE")
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

jq --indent "$(file_indent "$REGISTRY_DIR/chain.json")" \
   --arg tag "$TAG_NAME" \
   --arg go_version "$GO_VERSION" \
   --arg sdk_version "$SDK_VERSION" \
   --arg cometbft_version "$COMETBFT_VERSION" \
   --arg wasmd_version "$WASMD_VERSION" \
   --arg ibc_version "$IBC_VERSION" \
   --argjson binaries "$BINARIES" \
   '.codebase.tag = $tag |
    .codebase.recommended_version = $tag |
    .codebase.language.version = $go_version |
    .codebase.binaries = $binaries |
    .codebase.sdk.version = $sdk_version |
    .codebase.consensus.version = $cometbft_version |
    .codebase.cosmwasm.version = $wasmd_version |
    .codebase.ibc.version = $ibc_version' \
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
  --arg sdk_version "$SDK_VERSION" \
  --arg cometbft_version "$COMETBFT_VERSION" \
  --arg wasmd_version "$WASMD_VERSION" \
  --arg ibc_version "$IBC_VERSION" \
  --argjson binaries "$BINARIES" \
  --argjson height "$HEIGHT" \
  --argjson proposal "$PROPOSAL" \
  '{name: $name, tag: $tag, recommended_version: $tag,
    compatible_versions: [$tag], height: $height, proposal: $proposal,
    language: {type: "go", version: $go_version},
    binaries: $binaries,
    sdk: {type: "cosmos", version: $sdk_version},
    consensus: {type: "cometbft", version: $cometbft_version},
    cosmwasm: {version: $wasmd_version, enabled: true},
    ibc: {type: "go", version: $ibc_version}}')

jq --indent "$(file_indent "$REGISTRY_DIR/versions.json")" \
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

# xion-assets — CLAUDE.md

Frontend asset hub for Xion. Hosts chain registry data (served via the app), token lists, and chain configuration for wallets and explorers.

## Repository Structure

```
public/chain-registry/
  xion/               # Mainnet chain.json, assetlist.json, versions.json
  testnets/
    xiontestnet2/     # Testnet chain.json, assetlist.json, versions.json
src/                  # Frontend source
sources/              # Data sources (chain-registry, keplr, chainlist, xion-explorer)
```

## GitHub Workflows

### `update_chain_registry.yaml`

**Triggered by:**
- `workflow_call` from **`burnt-labs/xion`** `release-downstream.yaml` — fires on **every** xion release (rc and stable)
- `repository_dispatch` event type: `xion-assets-release-trigger`
- `workflow_dispatch` — manual with input: `release_tag`

**What it does:**
1. Fetches release checksums from `https://github.com/burnt-labs/xion/releases/download/<tag>/xiond-<version>-checksums.txt`
2. Reads `go.mod` from the release tag to extract SDK/IBC/cosmwasm versions
3. Updates `public/chain-registry/xion/versions.json` with the new version entry
4. Updates `public/chain-registry/xion/chain.json` codebase section
5. Creates a PR

### `sync_to_cosmos_chain_registry.yaml`

**Triggered by:** Push to `main` (path filter: `public/chain-registry/**`)

**What it does:**
- Creates PRs to `cosmos/chain-registry` and `burnt-labs/chain-registry` with updated xion chain data

### `ai_pr_bot.yaml`

AI-assisted PR review on pull request events.

### `test-gemfury-packages.yaml`

**Triggered by:** Schedule (Monday 12:00 PM EET) + manual

Tests that Gemfury-distributed packages install correctly.

## Upstream Triggers

| Source | Workflow | Condition |
|--------|----------|-----------|
| `burnt-labs/xion` | `release-downstream.yaml` | Any xion release published |

## Downstream Triggers

| Target | How | Condition |
|--------|-----|-----------|
| `cosmos/chain-registry` | PR via `sync_to_cosmos_chain_registry.yaml` | Push to main with chain-registry changes |
| `burnt-labs/chain-registry` | PR via `sync_to_cosmos_chain_registry.yaml` | Push to main with chain-registry changes |

## Updating Chain Registry Manually

When chain registry data needs manual updates:
1. Edit `public/chain-registry/xion/chain.json` — update `codebase.tag`, `recommended_version`, binaries, SDK versions
2. Edit `public/chain-registry/xion/versions.json` — add new version entry
3. Push to main → `sync_to_cosmos_chain_registry.yaml` will create PRs upstream

## Secrets Required

| Secret | Purpose |
|--------|---------|
| `GH_TOKEN_FOR_RELEASE_AUTOMATION` | Push to chain-registry repos |
| `GH_TOKEN_FOR_RELEASE_AUTOMATION_2` | Alternate token for PRs |
| `CLAUDE_API_KEY` | AI PR bot |
| `GEMFURY_API_TOKEN` | Package testing |
| `NOTIFY_DEVOPS_SLACK_APP_BOT_TOKEN` | Slack notifications |

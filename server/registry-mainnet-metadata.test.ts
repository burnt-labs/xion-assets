import chainJson from "../public/chain-registry/xion/chain.json?raw";
import versionsJson from "../public/chain-registry/xion/versions.json?raw";
import { describe, expect, it } from "vitest";

// Published release checksums and effective dependencies from the release go.mod:
// https://github.com/burnt-labs/xion/releases/tag/v32.0.1
// https://github.com/burnt-labs/xion/blob/v32.0.1/go.mod
const tag = "v32.0.1";
const checksums = {
  "darwin/amd64":
    "43063e7534bd973b65c31f9014354ca9727e1f29ab7caf110aac878ce949d481",
  "darwin/arm64":
    "d847728cee12b8ec26d860bcd3dec2f77a6f84708a66c7e97767c4f03d8d3038",
  "linux/amd64":
    "d7fe602812cdb50884ba0f4d1b302c16472e6a9f71a8a3354eccc517cd897937",
  "linux/arm64":
    "a5099792fe901d2dfc2ea2d747dd62a3ade64dadf8ab62b0a2ac17f5a235759d",
};
const chain = JSON.parse(chainJson);
const versions = JSON.parse(versionsJson);
const version = versions.versions.find(
  (entry: { tag: string }) => entry.tag === tag,
);

describe.each([
  // Release fixtures remain valid after a later recommendation is selected.
  ...(chain.codebase.tag === tag
    ? [["chain.json codebase", chain.codebase]]
    : []),
  ["versions.json release", version],
])("%s", (_name, metadata) => {
  it.each(Object.entries(checksums))(
    "uses the published %s asset name and checksum without changing the release path",
    (platform, checksum) => {
      expect(metadata.binaries[platform]).toBe(
        `https://github.com/burnt-labs/xion/releases/download/${tag}/xiond_${tag.slice(1)}_${platform.replace("/", "_")}.tar.gz?checksum=sha256:${checksum}`,
      );
    },
  );

  it("records schema-compatible IBC version and exact module provenance", () => {
    expect(metadata.ibc).toMatchObject({
      type: "go",
      version: "v11",
      repo: "https://github.com/cosmos/ibc-go",
      tag: "v11.0.0-20261019144822-2757a8778d05",
    });
  });

  it("records the effective wasmd replacement, not the upstream requirement", () => {
    expect(metadata.cosmwasm).toMatchObject({
      version: "v0.70.5",
      repo: "https://github.com/burnt-labs/wasmd",
      tag: "v0.70.5-xion.4",
      enabled: true,
    });
  });

  it("preserves the recommendation and declares it compatible", () => {
    expect(metadata.tag).toBe(tag);
    expect(metadata.recommended_version).toBe(tag);
    expect(metadata.compatible_versions).toContain(tag);
  });
});

it("keeps codebase compatibility aligned with its recommended release", () => {
  const recommended = versions.versions.find(
    (entry: { tag: string }) =>
      entry.tag === chain.codebase.recommended_version,
  );
  expect(recommended).toBeDefined();
  expect(chain.codebase.tag).toBe(recommended.tag);
  expect(chain.codebase.compatible_versions).toContain(
    chain.codebase.recommended_version,
  );
  expect(chain.codebase.compatible_versions).toEqual(
    recommended.compatible_versions,
  );
});

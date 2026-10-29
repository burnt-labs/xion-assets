import chainJson from "../public/chain-registry/testnets/xiontestnet2/chain.json?raw";
import versionsJson from "../public/chain-registry/testnets/xiontestnet2/versions.json?raw";
import { describe, expect, it } from "vitest";

// Published release checksums and effective dependencies from the release go.mod:
// https://github.com/burnt-labs/xion/releases/tag/v32.0.1-rc1
// https://github.com/burnt-labs/xion/blob/v32.0.1-rc1/go.mod
const tag = "v32.0.1-rc1";
const checksums = {
  "darwin/amd64":
    "6c5006ed1dd52fb5acf7aa5a377af22c2da93a3d3348db1e575353efc93a8365",
  "darwin/arm64":
    "836ef1a83ed5307951e4fbc4cbd827c68769d0a9c4908f8ba829e31057628ba7",
  "linux/amd64":
    "65143455e2f93e3694890dfd8ab569f49b1fbfb2a9b55610d0c4f7dab79e2dd1",
  "linux/arm64":
    "feb0073fcfa288c4763c2cd87ed5b7b72a7e30ed7f9cf1957914995a5bfb688c",
};
const chain = JSON.parse(chainJson);
const versions = JSON.parse(versionsJson);
const version = versions.versions.find(
  (entry: { tag: string }) => entry.tag === tag,
);

describe.each([
  ["chain.json codebase", chain.codebase],
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

it("keeps codebase compatibility aligned with the selected release", () => {
  expect(chain.codebase.compatible_versions).toEqual(
    version.compatible_versions,
  );
});

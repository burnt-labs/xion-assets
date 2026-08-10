import { describe, expect, it } from "vitest";

import worker from "./index";

describe("asset worker", () => {
  it("returns service metadata for API requests", async () => {
    const response = await worker.fetch(
      new Request("https://assets.xion.burnt.com/api/health"),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ name: "Xion-Assets" });
  });

  it("returns not found for non-API requests", async () => {
    const response = await worker.fetch(
      new Request(
        "https://assets.xion.burnt.com/chain-registry/xion/chain.json",
      ),
    );

    expect(response.status).toBe(404);
  });
});

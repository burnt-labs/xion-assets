import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["server/**/*.test.ts"],
    coverage: {
      provider: "v8",
      include: ["server/**/*.ts"],
      exclude: ["server/**/*.test.ts"],
      thresholds: {
        lines: 100,
        functions: 100,
        branches: 100,
        statements: 100,
      },
    },
  },
});

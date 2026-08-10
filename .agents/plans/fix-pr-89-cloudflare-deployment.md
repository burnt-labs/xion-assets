# Fix PR #89 Cloudflare deployment

## Evidence

- PR #89 fails only `Workers Builds: xion-assets`.
- Cloudflare build `a906cd07-1f40-4c69-a76f-c5a32c8186ec` cannot initialize because its selected build token was deleted or rolled.
- The PR head installs with zero npm vulnerabilities and completes its Vite build and Wrangler dry run locally.
- The repository has no GitHub Actions path that can deploy the Worker.

## Plan

1. Add repository-owned quality and deployment policies for the existing npm Worker.
2. Add reusable GitHub Actions callers for required quality, PR previews, and automatic main promotion.
3. Add focused Worker tests with full coverage plus lint and formatting checks.
4. Validate the policy files, workflow syntax, install, audit, lint, formatting, type checking, tests, coverage, build, and Wrangler dry run.
5. Push the changes and verify the replacement GitHub Actions checks.
6. Remove the obsolete Cloudflare Workers Builds triggers after the GitHub Actions path succeeds.

## Execution

- GitHub Actions run `31438642875` completed the policy, quality, preview URL
  enablement, candidate upload, and preview publication jobs successfully.
- Cloudflare identified `xion-assets` by Worker tag
  `fa091517d6904b8dba9abbbef08d2a1e`.
- Deleted the matching non-production trigger
  `8793c58f-f256-4f3a-a53d-13c03f916812` and production trigger
  `1187a6ee-c2ac-4615-aef0-bcd24ef095c1` only after the replacement preview
  succeeded.
- A fresh Cloudflare Builds API query returned zero remaining triggers for the
  Worker tag.

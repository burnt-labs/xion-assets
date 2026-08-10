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

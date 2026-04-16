---
task: repo-bootstrap
timestamp_utc: 2026-04-09T18:53:15Z
owner: github:@amanshresthaa
reviewers: [github:@maintainers]
risk: low
flags: []
related_tickets: []
---

# Research: Repo Bootstrap

## Requirements

- Functional:
  - Get `automazeio/vibeproxy` into a usable local workspace.
  - Identify the project structure, build entrypoints, and baseline health.
- Non-functional (a11y, perf, security, privacy, i18n):
  - Preserve existing source state before product changes.
  - Avoid introducing secrets or unsupported local auth artifacts.

## Existing Patterns & Reuse

- Build and packaging are driven by `Makefile`, `build.sh`, and `create-app-bundle.sh`.
- Swift package sources live in `src/Sources`.
- Logic tests live in `src/Tests`.

## External Resources

- [GitHub repository](https://github.com/automazeio/vibeproxy) - upstream source of truth for the project.

## Constraints & Risks

- Direct `git clone` over HTTPS hung in this environment after initializing the repository metadata.
- A GitHub archive download was used as a fallback to obtain a working source tree.
- The local checkout currently does not include upstream commit history.

## Open Questions (owner, due)

- Q: Do we need a full Git clone with history before making code changes?
  A: Pending user preference after initial orientation.

## Recommended Direction (with rationale)

- Use the extracted source tree for inspection and implementation work immediately.
- If commit history becomes necessary, troubleshoot the HTTPS clone separately without blocking product work.

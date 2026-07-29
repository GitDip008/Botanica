## gstack

Use /browse from gstack for all web browsing. Never use mcp__claude-in-chrome__* tools.

Available skills: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review,
/design-consultation, /design-shotgun, /design-html, /review, /ship, /land-and-deploy,
/canary, /benchmark, /browse, /open-gstack-browser, /qa, /qa-only, /design-review,
/setup-browser-cookies, /setup-deploy, /setup-gbrain, /sync-gbrain, /retro, /investigate,
/document-release, /document-generate, /codex, /cso, /autoplan, /pair-agent, /careful, /freeze,
/guard, /unfreeze, /gstack-upgrade, /learn.

## Skill routing for this project

Botanica is a Flutter app with an AI agent wired to a live production REST API
(Garden Information System) and in-tree navigation (lib/navigation/).

- New feature: /office-hours -> /autoplan (CEO+design+eng+DX review), then implement.
- Architecture work (nav <-> live-DB, beacon/section-code crosswalk): /plan-eng-review first.
- Security: /cso before any change touching the production API or auth. App Check is
  currently OFF (GitHub/sideloaded distribution) and the agent reads+writes live data, so
  treat the trust boundary as exposed until App Check is re-enforced at store launch.
- UI: /plan-design-review (before) and /design-review (after) on Flutter screens.
- Before merge: /review, then /codex for a second-model opinion. Ship with /ship.
- Debugging: /investigate (root cause, no fix without investigation).

Caveat: /qa, /browse, /design-review drive a Chromium browser, so they only exercise the
Flutter *web* build -- not the Android app on a device. Skip them for mobile-native testing.

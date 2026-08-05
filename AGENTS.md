# Agent Instructions

Before working on this repository, invoke the `agent-canvas-app` skill if it exists:

```
invoke_skill("agent-canvas-app")
```

This skill contains the platform conventions, deployment templates, Traefik
OAuth guard setup, and style guide for agent-canvas apps on the all-hands
staging cluster (`agent-canvas-apps` namespace).

Repo-specific notes:

- This app is a **helm release named `acmskin`** (not a Deployment/ConfigMap
  app). There is **no vendored chart**: `deploy.sh` clones
  OpenHands/OpenHands branch `feature/skins` and installs its live
  `helm/agent-canvas` chart (override the branch with `CHART_REF`).
- Read the "Sharp edges" section of README.md before renaming anything:
  the `acmskin` (no hyphen) resource naming avoids the kubelet
  `ACM_SKIN_PORT` service-link env collision, and the release name must
  not start with `acm-` or ACM fleet listings pick it up.
- The ACM skin source lives in **OpenHands/skin-acm** (main branch) — its
  own skin repo like skin-datadog-monitor / skin-linear-admin — not in
  this repo (and no longer in app-acm; the old `feature/skin-format`
  branch there is superseded). To pick up skin changes on the live
  instance: `POST /skin-api/pull` (with the session key) on acmskin-0, or
  uninstall/reinstall via `/skin-api`.
- The skin-acm backend fetches the agent-canvas helm chart **live from
  GitHub** at deploy time (`ACM_CHART_REPO`/`ACM_CHART_REF`/
  `ACM_CHART_PATH`, default OpenHands/OpenHands@feature/skins
  helm/agent-canvas, cached 10 min). Because that chart defaults
  `config.skin.repo` to the ACM skin, `helm_deploy` always sets
  `config.skin.repo` explicitly (selected skin or `""`).
- **After `/skin-api/pull`, verify the skin backend actually restarted**
  (`ps` for `start-skin.py` inside acmskin-0 and check
  `/skin-api/status` shows `running:true` with no port-bind error in
  `~/.openhands/agent-canvas/skin/skin.log`). A stale old process can
  keep port 18002 bound so the restarted backend crash-loops with
  `Errno 98` and the live ACM keeps serving the *old* code; kill the
  stale pid and the supervisor respawns the new one.
- Instances ACM provisions serve the skin natively at `/` on port 8000 —
  their ingress is a single `/ → 8000` path (the live chart has no
  skinGateway sidecar; the legacy vX.Y.Z gateway path was dropped along
  with the vendored chart, so provisioning is skins-image only).
- Since feature/skins commit `e4e89e1` (image `sha-e4e89e1`), the skin is
  **nested inside the Canvas UI**: `/` no longer rewrites to `/skin/` —
  it 308s to `/canvas/`, whose index route redirects into the `/skin`
  iframe tab when a skin is installed. The skin app is still proxied
  verbatim at `/skin/` (backend at `/skin/api/*`). The earlier bullet
  about "serve the skin natively at /" is superseded; ingress routing
  (single `/ → 8000`) is unchanged.
- Datadog skin auth: `ddpat_…` personal access tokens need
  `Authorization: Bearer`, NOT the `DD-API-KEY`/`DD-APPLICATION-KEY`
  pair, and the org may live on a non-default site (ours:
  `us5.datadoghq.com`, stored as the `DATADOG_SITE` secret on the
  instance). A 401 from `api.datadoghq.com` with a ddpat token usually
  means wrong site and/or wrong header style.
- Skin secrets live on the instance's agent-server:
  `PUT /api/settings/secrets` with JSON `{name, value, description}`
  (there is no per-name POST/PUT; `POST …/secrets/<name>` returns 405).
- Since feature/skins commit `cb8e5be` (image `sha-cb8e5be`), the skin
  checkout lives **in the agent workspace at `~/workspace/skin`** (was
  `~/.openhands/agent-canvas/skin/repo`; migrated automatically on boot).
  The Canvas static-server supervises it (own process group, SIGKILL
  backstop — no more orphaned `node server.js` holding the port) and
  `POST /skin-api/restart` (session key) applies agent edits. Service
  state + `skin.log` stay in `~/.openhands/agent-canvas/skin/`.
  `/skin-api/status` now reports the checkout `path`.
- skin.yaml supports `icon: <lucide-name>` (kebab-case, placed under
  `name:`), rendered on the skin's left-nav entry via
  `lucide-react/dynamic` (falls back to the Palette icon when absent or
  invalid; validated server-side by `sanitizeIconName`). Since image
  `sha-8a5a2c0`.
- Every skin repo must ship a root `SKILL.md` describing what the skin
  does. On every skin start/restart/pull the skin service renders it
  (frontmatter replaced, `description:` kept, no `triggers:`) to
  `~/.openhands/skills/skin-app.md` — a legacy always-active skill whose
  full content lands in the agent's system prompt at the start of every
  conversation. Removed on uninstall; new installs without SKILL.md are
  rejected. Since image `sha-05cfc33`.
- Docker builds on OpenHands `feature/skins` do NOT auto-trigger on push
  (docker.yml only fires on main/tags/PRs-to-main). Dispatch manually:
  `POST /repos/OpenHands/OpenHands/actions/workflows/docker.yml/dispatches`
  with `{"ref":"feature/skins"}`.
- The `skin` skill ACM injects (skin-acm `skin/SKILL.md`, installed to
  `~/.openhands/skills/installed/skin/SKILL.md`) was rewritten for this
  architecture (edit → restart → verify loop; screenshot must include the
  Canvas chrome and be embedded in the repo README; the old top-left
  "← Agent Canvas" link requirement is gone; skins should use top-level
  horizontal navigation, never a left-hand sidebar). ACM only installs it
  at provision time — after changing it, re-push it onto live instances
  (kubectl exec + cat, per pod).

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
  app). The chart in `chart/` is vendored from OpenHands/OpenHands branch
  `feature/skins` — refresh it from that branch, not main.
- Read the "Sharp edges" section of README.md before renaming anything:
  the `acmskin` (no hyphen) resource naming avoids the kubelet
  `ACM_SKIN_PORT` service-link env collision, and the release name must
  not start with `acm-` or ACM fleet listings pick it up.
- The ACM skin source lives in OpenHands/app-acm branch
  `feature/skin-format`, not in this repo. To pick up skin changes on the
  live instance: `POST /skin-api/pull` (with the session key) on
  acmskin-0, or uninstall/reinstall via `/skin-api`.
- **After `/skin-api/pull`, verify the skin backend actually restarted**
  (`ps` for `start-skin.py` inside acmskin-0 and check
  `/skin-api/status` shows `running:true` with no port-bind error in
  `~/.openhands/agent-canvas/skin/skin.log`). A stale old process can
  keep port 18002 bound so the restarted backend crash-loops with
  `Errno 98` and the live ACM keeps serving the *old* code; kill the
  stale pid and the supervisor respawns the new one.
- Instances ACM provisions on skins-capable (non-semver) image tags serve
  the skin natively at `/` on port 8000 — their ingress must be a single
  `/ → 8000` path and **no** `skinGateway` sidecar. Tagged releases
  (vX.Y.Z) still use the legacy gateway (`/ → 8081`). This is handled by
  `native_skins` in app-acm `backend/server.py::helm_deploy` (commit
  `b1a310c`); a wrong `/ → 8081` route makes an installed skin look like
  it "didn't take hold" (the gateway 302s to /canvas).

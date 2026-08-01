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

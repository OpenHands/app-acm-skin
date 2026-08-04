# acm-skin — branch ACM running as an Agent Canvas skin

An Agent Canvas instance built from the **skins-capable image**
(`ghcr.io/openhands/agent-canvas:sha-05cfc33`, from OpenHands/OpenHands
branch `feature/skins`, PR #16232) with the **Agent Canvas Manager (ACM)
installed as its skin** (OpenHands/app-acm branch `feature/skin-format`,
app-acm PR #1). ACM appears as the default "Agent Canvas Manager" tab of
the Canvas UI and can itself provision new Canvas instances with skins
picked from the marketplace.

- **Live URL:** <https://acm-skin.apps.staging.all-hands.dev>
- Skin status: `https://acm-skin.apps.staging.all-hands.dev/skin-api/status`
- The ACM app itself is served at `/` (and verbatim under `/skin/`); the
  Canvas UI lives at `/canvas`.
- Instances it creates land at `acm-<name>.apps.staging.all-hands.dev`
  (same fleet as the standalone [acm](https://github.com/OpenHands/app-acm)
  app — both list `acm-*` helm releases).

## How it differs from the `acm` app

The standalone `acm` app is a Deployment of a stdlib-Python backend +
static SPA with vendored chart ConfigMaps. **This** app is a full Agent
Canvas (StatefulSet from the `feature/skins` helm chart) whose skin
service clones app-acm@feature/skin-format on first boot, runs its
`npm run start` (→ `start-skin.py` → `backend/server.py`) on
`OPENHANDS_SKIN_PORT` (18002), reverse-proxies it verbatim under `/skin`
(and serves it at `/` as the instance's front page), and
adds it as the top sidebar item / default tab. Skin management lives at
`/skin-api/*` and Settings → Skin.

Because it's a real Canvas, the instance also has its own agent — you can
chat with it, and it manages the fleet through the embedded ACM.

## Layout

- `chart/` — vendored `helm/agent-canvas` chart from OpenHands/OpenHands
  branch `feature/skins` (defaults `config.skin.repo` to app-acm).
- `k8s/values.yaml` — the values for this instance: image tag pinned to
  `sha-05cfc33`, skin ref `feature/skin-format`, RBAC in
  `agent-canvas-apps`, OAuth-guarded ingress, secrets wiring.
- `deploy.sh` — `helm upgrade --install` + post-boot kubectl/helm
  bootstrap onto the persistent workspace volume.

## Deploy

One-off secrets (values from the environment; never in the repo):

```bash
# session API key for the instance:
kubectl create secret generic acm-skin-session -n agent-canvas-apps \
  --from-literal=sessionApiKey="$(python3 -c 'import secrets;print(secrets.token_urlsafe(32))')"

# GitHub token — REQUIRED: app-acm is private (the skin clone needs it) and
# the marketplace + skin repos (skin-datadog-monitor, skin-linear-admin)
# are private too:
kubectl create secret generic acm-skin-github -n agent-canvas-apps \
  --from-literal=token="$GITHUB_PERSONAL_ACCESS_TOKEN"

# global-store key (shared with the acm app; usually already exists):
kubectl create secret generic acm-store -n agent-canvas-apps \
  --from-literal=session-key="<store instance X-Session-API-Key>"
```

Then:

```bash
./deploy.sh
```

## Verify

```bash
kubectl -n agent-canvas-apps exec acmskin-0 -- curl -s http://127.0.0.1:8000/skin-api/status
# → {"installed":true,"name":"Agent Canvas Manager",...,"running":true,"error":null}
kubectl get certificate acmskin-tls -n agent-canvas-apps   # READY=True
```

Open <https://acm-skin.apps.staging.all-hands.dev> — the default tab is
"Agent Canvas Manager". In ACM, click **New backend**, pick a skin (e.g.
Datadog Monitor) from the marketplace grid, create — the new instance
boots on `sha-05cfc33` with `config.skin.repo` set and comes up with that
skin as its default tab.

## Sharp edges (learned the hard way)

1. **Never name a Service `acm-skin` (or `acm-anything_underscore-free`)
   that upcases to `ACM_SKIN`.** Kubelet injects Docker-link envs
   (`ACM_SKIN_PORT=tcp://<clusterIP>:8000`) into every pod in the
   namespace, which crashes the ACM backend (`int(ACM_SKIN_PORT)`) on its
   next restart — including the standalone `acm` app. That's why the helm
   release and `fullnameOverride` are **`acmskin`** and the values file
   additionally pins `ACM_SKIN_PORT=8081` in `extraEnv` for this pod.
2. **The skins image ships no kubectl/helm.** The ACM backend shells out
   to both; `deploy.sh` installs them to `~/workspace/bin` (persistent
   volume) and `values.yaml` puts that on `PATH`.
3. **Private skin repos need `GITHUB_TOKEN` on the *child* instance.**
   The skin-service clones `OPENHANDS_SKIN_REPO` with `GITHUB_TOKEN`.
   app-acm@feature/skin-format (commit `cacd1e0`) makes ACM pass a
   `secretKeyRef` to the `acm-github` Secret into every instance it
   creates with a marketplace skin. This host's own clone of app-acm uses
   the `acm-skin-github` Secret the same way.
4. **The marketplace list is on a branch.** `skins/marketplace.json`
   lives on OpenHands/extensions branch `feature/skins-marketplace`
   (until PR #433 merges); `ACM_MARKETPLACE_URL` points there.
5. **The release name must not start with `acm-`** or ACM instances
   (this one included) would list this host as a managed instance.

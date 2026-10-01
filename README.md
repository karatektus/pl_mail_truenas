# plMail for TrueNAS

The [plMail](https://github.com/karatektus/pl_mail) app definition for the TrueNAS Apps
catalog: `ix-dev/community/plmail`, laid out exactly as it sits in
[truenas/apps](https://github.com/truenas/apps).

## How it reaches the Discover page

TrueNAS 24.10 and later read one catalog, `github.com/truenas/apps`. The address is fixed
in the middleware; "Manage Catalogs → Add Catalog" existed up to 24.04 and was removed with
the move from Kubernetes to Docker. So there is no source to add: plMail shows up under
**Apps → Discover** once this directory is merged into `truenas/apps` (train `community`).

To submit it:

1. Fork `truenas/apps` and copy `ix-dev/community/plmail` into the fork.
2. Open a pull request. Attach the icon and screenshots: reviewers upload them to
   the TrueNAS CDN and hand back the URLs that replace the GitHub ones in `app.yaml`
   and `item.yaml`.
3. After the merge, Renovate in that repository bumps the image tags on each plMail
   release. Nothing has to be released from here.

Until then, `truenas.compose.yaml` in the plMail repository remains the way to install
(Apps → Discover → ⋮ → Install via YAML).

## What the install form asks

| Setting | Default | |
|---|---|---|
| **plMail Data Storage** | Host Path, required | The one dataset. Database, attachments, raw mail, uploads and the generated secrets all live in it. ixVolume is the alternative if you would rather not pick one. |
| WebUI Port | `30504` | Any port, or bind mode *None* when using a dedicated IP. |
| Networks | none | Join the `plmail` container to an existing macvlan/ipvlan network and set its IPv4 address to give plMail its own IP. It then answers on port 80 of that address. |
| Timezone, Additional Environment Variables, Labels, Resources | | Standard catalog fields. Nothing needs filling in. |

Secrets are not asked for. `secrets-init` generates them into `<data>/secrets` on first
start, as in `truenas.compose.yaml`. The directory layout is the same, so
pointing the data storage at the directory of an install made from that file should adopt
it; that path has not been tested.

Additional environment variables go to the web container and every worker. They may
replace `APP_PUBLIC_URL`, `MERCURE_PUBLIC_URL`, `TRUSTED_PROXIES`, `VAPID_*`,
`GOOGLE_OAUTH_*`, `GMAIL_PUBSUB_*`, `MICROSOFT_OAUTH_*` and `MAILER_DSN`.

## Differences from truenas.compose.yaml

- Images are pinned by tag and digest (`ix_values.yaml`); the catalog does not use `latest`.
- Mercure is pinned to `v0.24.2`. Mercure 1.0 dropped `/healthz` and changed how JWT keys
  are configured, so the unpinned `dunglas/mercure` no longer comes up healthy.
- Containers drop all capabilities and get back only what they use (see `app.yaml`).
- The Postgres directory is chowned to uid 70, the `postgres` user of the alpine image.

## Testing

```bash
scripts/test.sh
```

Clones `truenas/apps` into `.truenas-apps/`, copies the app in and runs the catalog's own
`ci.py`: render, deploy, wait for every container to be healthy, tear down. It also
re-vendors `templates/library` and refreshes `lib_version_hash` and `item.yaml`, which are
copied back here. `capabilities` and `run_as_context` in `app.yaml` were written by hand in
the format of the catalog's `generate_metadata.py`; run that script in the fork before the
pull request. Needs Docker on x86-64 Linux; the catalog's
validation image is amd64-only and its file writes fail under emulation on Apple Silicon.
The GitHub workflow runs the same script for both files in `templates/test_values`.

```bash
TEST_FILE=hostpath-values.yaml scripts/test.sh --wait=true
```

## Releasing a new plMail version (before the upstream merge)

In `ix-dev/community/plmail`: set `app_version` in `app.yaml`, the tag and digest of
`image` in `ix_values.yaml`, and raise `version` in `app.yaml`. The digest:

```bash
docker buildx imagetools inspect ghcr.io/karatektus/pl_mail:0.2.53
```

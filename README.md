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
2. Open a pull request. Attach the icon and screenshots: `app.yaml` and `item.yaml`
   already name them under `media.sys.truenas.net/apps/plmail/`, which the catalogue's
   tooling insists on, and reviewers upload the files there. Until they do, those
   URLs answer nothing. The files to attach are in the plMail repository:
   `public/icons/icon-512.png`, and `inbox.png`, `thread.png`, `compose.png` and
   `calendar.png` from `docs/screenshots/`, in that order.
3. After the merge, Renovate in that repository bumps the image tags on each plMail
   release. Nothing has to be released from here.

Until then, `truenas.compose.yaml` in the plMail repository remains the way to install
(Apps → Discover → ⋮ → Install via YAML).

## What the install form asks

| Setting | Default | |
|---|---|---|
| **Database Password** | none, required | The one field that has to be filled in. The catalogue's Postgres helper needs it when the app is rendered. No spaces. |
| plMail Data Storage | ixVolume | Attachments, raw mail, uploads and the generated secrets, including the key that encrypts stored mailbox passwords. |
| Postgres Data Storage | ixVolume | The database. |
| Additional Storage | none | Extra mounts into the `plmail` and `worker` containers. |
| User and Group | 568 / 568 | The user `plmail` and `worker` run as. |
| WebUI Port | `30519` | Any port, or bind mode *None* when using a dedicated IP. |
| Networks | none | Join the `plmail` container to an existing macvlan/ipvlan network and set its IPv4 address to give plMail its own IP. It then answers on port 80 of that address. |
| Timezone, Postgres Image, Additional Environment Variables, Labels, Resources | | Standard catalogue fields. Nothing needs changing. |

plMail's own secrets are not asked for. Its entrypoint generates them into `<data>/secrets`
on first start.

## Differences from truenas.compose.yaml

The catalogue has rules of its own, and the app follows them rather than the compose file:

- **Postgres comes from the catalogue's helper**: `postgres:18-trixie` as uid 999 in a
  storage of its own, with the password from the form. The compose file runs
  `postgres:18-alpine` inside the one data directory with a generated password. The two
  layouts are not interchangeable: moving an install from one to the other goes through
  plMail's backup and restore, not through pointing at the old directory.
- **No `secrets-init` container.** The web and worker containers generate the secrets
  themselves, which they have always been able to do.
- **Containers are `plmail`, `worker`, `postgres`** plus the helper's short-lived
  `permissions` and `postgres_upgrade`. The hub runs in `worker` and is reached by that
  name (`MERCURE_URL`, `MERCURE_UPSTREAM`), not through a `mercure` alias.
- **Only what the template owns is set**: paths, the database URL and where the hub is.
  Everything else is plMail's own default or an additional environment variable.
- Images are referenced by tag and digest; Renovate moves them forward in `truenas/apps`.
- `plmail` and `worker` run as the user from the form, 568 by default, with every
  capability dropped. The compose file runs them as root.

Needs plMail 0.2.57 or later: 0.2.56 is where the image stopped depending on its compose
file for the cookie name, an absolute storage path and the hub's address, and 0.2.57 is
where it stopped needing root.

## Testing

```bash
scripts/test.sh
```

Clones `truenas/apps` into `.truenas-apps/`, copies the app in and runs the catalog's own
`ci.py`: render, deploy, wait for every container to be healthy, tear down. It also
re-vendors `templates/library` and refreshes `lib_version_hash` and `item.yaml`, which are
copied back here, and runs the catalogue's `generate_metadata.py`, which writes
`capabilities` and `run_as_context` in `app.yaml`. Needs Docker on x86-64 Linux; the catalog's
validation image is amd64-only and its file writes fail under emulation on Apple Silicon.
The GitHub workflow runs the same script for both files in `templates/test_values`.

```bash
TEST_FILE=custom-values.yaml scripts/test.sh --wait=true
```

## Releasing a new plMail version (before the upstream merge)

In `ix-dev/community/plmail`: set `app_version` in `app.yaml`, the tag and digest of
`image` in `ix_values.yaml`, and raise `version` in `app.yaml`. The digest:

```bash
docker buildx imagetools inspect ghcr.io/karatektus/pl_mail:0.2.57
```

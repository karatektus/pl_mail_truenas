#!/usr/bin/env bash
# Render and run the plMail app with the official TrueNAS catalog tooling.
#
#   scripts/test.sh                      render + deploy + wait for healthy, then tear down
#   scripts/test.sh --render-only=true   only render the compose file
#   scripts/test.sh --wait=true          keep it running until Ctrl+C
#   TEST_FILE=hostpath-values.yaml scripts/test.sh
#
# The app is copied into a checkout of truenas/apps (APPS_DIR, cloned on first
# use) because ci.py only works from inside that repository. What the tooling
# generates there (templates/library, lib_version_hash, item.yaml, and the
# capabilities and run_as_context in app.yaml) is copied back, since those
# files ship with the app.
#
# Needs only Docker: ci.py itself runs in a container, so no host Python.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPS_DIR="${APPS_DIR:-$ROOT/.truenas-apps}"
TRAIN=community
APP=plmail
TEST_FILE="${TEST_FILE:-basic-values.yaml}"
TOOLS_IMAGE=plmail-truenas-ci

if [ ! -d "$APPS_DIR/.git" ]; then
	git clone --depth 1 https://github.com/truenas/apps.git "$APPS_DIR"
fi
APPS_DIR="$(cd "$APPS_DIR" && pwd -P)"

docker build -q -t "$TOOLS_IMAGE" - >/dev/null <<'DOCKERFILE'
FROM docker:cli
RUN apk add --no-cache python3 py3-yaml py3-psutil bash jq openssl git
DOCKERFILE

rm -rf "$APPS_DIR/ix-dev/$TRAIN/$APP"
cp -R "$ROOT/ix-dev/$TRAIN/$APP" "$APPS_DIR/ix-dev/$TRAIN/$APP"

# Mounted at the same path as on the host: ci.py starts sibling containers
# through the socket and hands them paths under its working directory.
tools() {
	docker run --rm -i \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "$APPS_DIR:$APPS_DIR" -w "$APPS_DIR" \
		"$TOOLS_IMAGE" "$@"
}

status=0
tools python3 .github/scripts/ci.py --app "$APP" --train "$TRAIN" --test-file "$TEST_FILE" "$@" || status=$?

# capabilities and run_as_context in app.yaml, from what the template renders.
if [ "$status" -eq 0 ]; then
	tools python3 .github/scripts/generate_metadata.py --app "$APP" --train "$TRAIN" || status=$?
fi

# The tooling writes as root. Cleaned up and handed back from inside a
# container, because on a CI runner the invoking user may not remove those
# files: the first runs here passed every test and then failed on this rm.
tools sh -c "rm -rf 'ix-dev/$TRAIN/$APP/templates/rendered' && find 'ix-dev/$TRAIN/$APP' -name __pycache__ -type d -prune -exec rm -rf {} + && chown -R $(id -u):$(id -g) 'ix-dev/$TRAIN/$APP'"

rm -rf "$ROOT/ix-dev/$TRAIN/$APP"
cp -R "$APPS_DIR/ix-dev/$TRAIN/$APP" "$ROOT/ix-dev/$TRAIN/$APP"

exit "$status"

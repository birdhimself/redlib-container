#!/bin/sh
# Usage: smoke-test.sh IMAGE EXPECTED_VERSION
# Checks the binary's shared libraries resolve, the server starts and serves
# /settings, and it reports the expected version. Set DOCKER=podman if needed.
set -eu

image=$1
version=$2
docker=${DOCKER:-docker}
name=redlib-smoke-$$
port=${PORT:-18080}

cleanup() { "$docker" rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "== shared libraries"
libs=$("$docker" run --rm --entrypoint ldd "$image" /usr/local/bin/redlib 2>&1) || true
echo "$libs"
if echo "$libs" | grep -Eq 'not found|Error'; then
	echo "FAIL: unresolved libraries or symbols" >&2
	exit 1
fi

echo "== startup"
"$docker" run -d --name "$name" -p "127.0.0.1:$port:8080" "$image" >/dev/null
ok=
for _ in $(seq 30); do
	if curl -sf -o /dev/null "http://127.0.0.1:$port/settings"; then
		ok=1
		break
	fi
	sleep 1
done
"$docker" logs "$name" 2>&1
if [ -z "$ok" ]; then
	echo "FAIL: /settings did not respond within 30s" >&2
	exit 1
fi

echo "== healthcheck command"
"$docker" exec "$name" wget --spider -q http://localhost:8080/settings

echo "== version"
if ! "$docker" logs "$name" 2>&1 | grep -Fq "Running Redlib v$version "; then
	echo "FAIL: expected 'Running Redlib v$version' in logs" >&2
	exit 1
fi

echo "OK"

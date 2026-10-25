#!/bin/sh
# Assemble the newest npm release of NPM_MAJOR into $1, then upgrade each
# bundled dependency named in NPM_DEPENDENCY_OVERRIDES to its newest release
# in the same major. Every tarball must match the registry integrity hash and
# carry a valid npm registry ECDSA signature.
set -eu

out="$1"
registry=https://registry.npmjs.org
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL --retry 5 --retry-all-errors "$registry/-/npm/v1/keys" -o "$work/keys.json"

# fetch NAME MAJOR DEST: download, verify and unpack the newest NAME@MAJOR.x.y.
fetch() {
  name="$1" major="$2" dest="$3"
  curl -fsSL --retry 5 --retry-all-errors \
    -H 'Accept: application/vnd.npm.install-v1+json' \
    "$registry/$name" -o "$work/meta.json"
  version="$(jq -r --arg major "$major" '
    [.versions | keys[] | select(test("^" + $major + "\\.[0-9]+\\.[0-9]+$"))]
    | sort_by(split(".") | map(tonumber)) | last // empty' "$work/meta.json")"
  test -n "$version" || { echo "no $name@$major.x release" >&2; exit 1; }
  jq --arg v "$version" '.versions[$v]' "$work/meta.json" > "$work/manifest.json"

  curl -fsSL --retry 5 --retry-all-errors \
    "$(jq -r .dist.tarball "$work/manifest.json")" -o "$work/package.tgz"

  integrity="$(jq -r .dist.integrity "$work/manifest.json")"
  actual="sha512-$(openssl dgst -sha512 -binary "$work/package.tgz" | base64 -w0)"
  test "$actual" = "$integrity" || { echo "$name@$version: integrity mismatch" >&2; exit 1; }

  keyid="$(jq -r '.dist.signatures[0].keyid // empty' "$work/manifest.json")"
  test -n "$keyid" || { echo "$name@$version: unsigned" >&2; exit 1; }
  jq -r --arg id "$keyid" '.keys[] | select(.keyid == $id) | .key' "$work/keys.json" |
    base64 -d > "$work/key.der"
  test -s "$work/key.der" || { echo "$name@$version: unknown key $keyid" >&2; exit 1; }
  openssl pkey -pubin -inform DER -in "$work/key.der" -out "$work/key.pem"
  jq -r '.dist.signatures[0].sig' "$work/manifest.json" | base64 -d > "$work/sig.der"
  printf '%s@%s:%s' "$name" "$version" "$integrity" > "$work/message"
  openssl dgst -sha256 -verify "$work/key.pem" -signature "$work/sig.der" "$work/message" >/dev/null ||
    { echo "$name@$version: bad registry signature" >&2; exit 1; }

  rm -rf "$dest"
  mkdir -p "$dest"
  tar -xzf "$work/package.tgz" -C "$dest" --strip-components=1
  echo "$name@$version verified"
}

fetch npm "$NPM_MAJOR" "$out"
for name in $NPM_DEPENDENCY_OVERRIDES; do
  bundled="$(jq -r .version "$out/node_modules/$name/package.json")"
  fetch "$name" "${bundled%%.*}" "$out/node_modules/$name"
done

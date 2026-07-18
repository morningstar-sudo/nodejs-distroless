# Distroless Node.js Docker Images — Node 22 & 24 on Wolfi (Zero-CVE, Nightly Rebuilds)

[![build](https://github.com/morningstar-sudo/nodejs-distroless/actions/workflows/build.yml/badge.svg)](https://github.com/morningstar-sudo/nodejs-distroless/actions/workflows/build.yml)
![Node 22](https://img.shields.io/badge/node-22-brightgreen)
![Node 24](https://img.shields.io/badge/node-24-brightgreen)
![Base: Wolfi](https://img.shields.io/badge/base-wolfi-blueviolet)

**Minimal, secure Node.js container images** for production: a full-toolchain
**builder** image and a truly **distroless runtime** image (no shell, no
package manager, non-root) for Node.js 22 and 24, built on
[Chainguard Wolfi](https://github.com/wolfi-dev). Every image is rebuilt
**nightly**, scanned with **Trivy under a strict gate** (build fails on any
CVE of any severity, including unfixed), and published to GitHub Container
Registry (ghcr.io).

## Available images

| Image | Node.js | Base | Size | Contents |
|---|---|---|---|---|
| `ghcr.io/morningstar-sudo/nodejs-distroless-22-builder` | 22.x | wolfi-base | ~1 GB | node, npm, node-gyp, gcc, make, python-3, git |
| `ghcr.io/morningstar-sudo/nodejs-distroless-24-builder` | 24.x | wolfi-base | ~1 GB | node, npm, node-gyp, gcc, make, python-3, git |
| `ghcr.io/morningstar-sudo/nodejs-distroless-22-runtime` | 22.x | glibc-dynamic | ~160 MB | node binary + shared libs only |
| `ghcr.io/morningstar-sudo/nodejs-distroless-24-runtime` | 24.x | glibc-dynamic | ~160 MB | node binary + shared libs only |

**Tags:** every build publishes `<git-sha>-<DDMMYYYY>` (immutable, pin this in
production) and `latest`. A scheduled rebuild runs every night at 15:00 UTC to
pick up patched Wolfi packages, so `latest` always carries yesterday's
security fixes at most.

## Quick start

Multi-stage Dockerfile — compile with the builder, ship the distroless runtime:

```dockerfile
FROM ghcr.io/morningstar-sudo/nodejs-distroless-22-builder:latest AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

FROM ghcr.io/morningstar-sudo/nodejs-distroless-22-runtime:latest
COPY --from=build /app /app
CMD ["server.js"]
```

The runtime image's entrypoint is `/usr/bin/node`, so `CMD` takes node
arguments directly (`CMD ["server.js"]` runs `node server.js`).

## Why these images

- **Truly distroless runtime.** The runtime stage copies only the `node`
  binary and its shared libraries (collected via `ldd`) onto
  `cgr.dev/chainguard/glibc-dynamic` — a base with glibc, CA certificates and
  nothing else. No `/bin/sh`, no busybox, no apk. An attacker who gains code
  execution inside the container has no shell and no package manager.
- **Non-root by default.** Runs as `nonroot` (uid 65532).
- **Zero-CVE target, enforced.** CI uses a strict Trivy gate: the pipeline
  fails on *any* CVE — every severity, unfixed included. Debian- and
  Alpine-based images can rarely pass such a gate; Wolfi's fast patch cadence
  makes it sustainable.
- **Nightly rebuilds.** Fresh Wolfi packages every night — no waiting for a
  human to cut a release after a CVE lands.
- **Builder/runtime glibc parity.** Both flavors come from the same Wolfi
  package set, so native addons (`.node` files) compiled in the builder run
  unchanged in the runtime. Verified end-to-end with better-sqlite3.

## Native modules (node-gyp, better-sqlite3, sharp, …)

Wolfi ships **npm 12, which blocks package install scripts by default** —
`npm install` succeeds but native addons are silently left uncompiled.
Approve the packages that need install scripts:

```sh
npm install-scripts approve better-sqlite3
npm install
```

The builder image carries the full native toolchain (gcc, make, python-3,
node-gyp). Addons compiled there are binary-compatible with the runtime image.

## Debugging a distroless container

There is no shell to `docker exec` into. Use an ephemeral debug container:

```sh
kubectl debug -it mypod --image=cgr.dev/chainguard/wolfi-base --target=app
# or locally:
docker debug <container>
```

## How it compares

| | This runtime | `gcr.io/distroless/nodejs` | `node:22-alpine` | `node:22-slim` |
|---|---|---|---|---|
| Shell / package manager | none | none | busybox + apk | bash + apt |
| Runs as non-root | yes | variant | no (default) | no (default) |
| libc | glibc (Wolfi) | glibc (Debian) | musl | glibc (Debian) |
| Passes strict all-severity CVE gate | yes | typically no (Debian unfixed CVEs) | varies | no |
| Rebuild cadence | nightly | Google's schedule | on Node release | on Node release |

`gcr.io/distroless` is excellent; the practical difference is CVE hygiene —
Debian-based bases carry long-lived unfixed low/medium CVEs that fail strict
scanning policies, while Wolfi patches within days.

## FAQ

**What does "distroless" mean?**
An image assembled from an explicit allowlist of files — application binary,
its shared libraries, CA certificates — with no OS userland: no shell, no
package manager, no coreutils. Smaller attack surface, smaller size, cleaner
scans.

**Why is the runtime 160 MB and not smaller?**
Node itself links `libicu` with full ICU data (~40 MB) plus V8. A smaller
image would require a custom Node build with `small-icu`; these images use
the stock Wolfi `nodejs-22`/`nodejs-24` packages for patch speed.

**Can I pin an exact version?**
Pin the immutable `<git-sha>-<DDMMYYYY>` tag, or pin by digest
(`@sha256:...`). `latest` moves nightly.

**How are the images built?**
GitHub Actions (`.github/workflows/build.yml`): a 2×2 matrix
(Node 22/24 × builder/runtime) builds each Dockerfile, scans with Trivy via
[`abxst/actions/strict`](https://github.com/abxst/actions) — failing on any
finding — then pushes to ghcr.io.

## License

Licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
Node.js, Wolfi packages and Chainguard base images retain their upstream
licenses.

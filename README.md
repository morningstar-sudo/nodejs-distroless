# nodejs-distroless

Wolfi-based Node.js images, rebuilt nightly and gated by a strict Trivy scan
(every severity, including unfixed) via `abxst/actions/strict@v3`.

## Images

| Image | Base | Contents |
|---|---|---|
| `ghcr.io/<owner>/nodejs-distroless-22-builder` | wolfi-base | node 22, npm, build-base, python-3, git |
| `ghcr.io/<owner>/nodejs-distroless-24-builder` | wolfi-base | node 24, npm, build-base, python-3, git |
| `ghcr.io/<owner>/nodejs-distroless-22-runtime` | glibc-dynamic | node 22 only — no shell, no package manager |
| `ghcr.io/<owner>/nodejs-distroless-24-runtime` | glibc-dynamic | node 24 only — no shell, no package manager |

Tags: `<git-sha>-<DDMMYYYY>` per build, plus `latest` on the default branch.
A cron rebuild runs every night (22:00 VN / 15:00 UTC) to pick up patched
Wolfi packages.

## Usage

```dockerfile
FROM ghcr.io/<owner>/nodejs-distroless-22-builder:latest AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .

FROM ghcr.io/<owner>/nodejs-distroless-22-runtime:latest
COPY --from=build /app /app
CMD ["server.js"]
```

The runtime image runs as `nonroot` (uid 65532) and has `node` as its
entrypoint. There is no shell — to debug a running container use an
ephemeral debug container (`kubectl debug`).

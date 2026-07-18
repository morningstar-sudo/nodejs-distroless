ARG NODE_VERSION=22
FROM cgr.dev/chainguard/wolfi-base

ARG NODE_VERSION
RUN apk add --no-cache \
    nodejs-${NODE_VERSION} \
    npm \
    build-base \
    python-3 \
    git

WORKDIR /app
CMD ["node"]

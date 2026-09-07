# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS builder

WORKDIR /src

# Cache dependencies
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code
COPY app/ ./app/

# Build static binary for target architecture
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-arm64} \
    go build -trimpath -ldflags="-s -w" -o /bin/devops-flex-api ./app

# Production Distroless Image
FROM gcr.io/distroless/static:nonroot

WORKDIR /
COPY --from=builder /bin/devops-flex-api /devops-flex-api

USER 65532:65532
EXPOSE 8080

ENTRYPOINT ["/devops-flex-api"]

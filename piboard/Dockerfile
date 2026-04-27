# Dockerfile - Build piboard for Raspberry Pi (ARM64)
#
# Multi-stage build: compile Go binary in builder, copy to distroless.
# Produces a minimal image with no shell or package manager.
#
# Build: docker build --platform linux/arm64 -t piboard .
# Run:   docker run -p 8080:8080 -v /path/to/config.yaml:/etc/piboard/config.yaml:ro piboard

# --- Builder ---
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS builder

ARG TARGETOS=linux
ARG TARGETARCH=arm
ARG TARGETVARIANT=v7

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download
COPY . .

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=7 \
    go build -ldflags="-s -w" -o piboard .

# --- Runtime ---
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /build/piboard /piboard
COPY config.yaml /etc/piboard/config.yaml

EXPOSE 8080

USER nonroot:nonroot

ENTRYPOINT ["/piboard", "--config", "/etc/piboard/config.yaml"]

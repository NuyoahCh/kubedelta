FROM golang:1.23-bookworm AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG TARGETARCH
ARG TARGETOS=linux
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o /out/kubedelta-extender ./cmd/kubedelta-extender

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/kubedelta-extender /kubedelta-extender
USER nonroot:nonroot
ENTRYPOINT ["/kubedelta-extender"]

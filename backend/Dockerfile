# Use a standard Go image that matches the version from the Makefile (1.24)
FROM golang:1.24 AS build-stage

# Install faketime
RUN mkdir -p /usr/local/go-faketime && \
    cp -r /usr/local/go/. /usr/local/go-faketime && \
    mkdir -p /root/gocache && \
    GOCACHE=/root/gocache /usr/local/go-faketime/bin/go install --tags=faketime std


# Install backend
COPY go.mod /go/src/backend/go.mod
COPY go.sum /go/src/backend/go.sum
WORKDIR /go/src/backend
RUN go mod download

COPY ./src /go/src/backend/src
WORKDIR /go/src/backend
RUN go install ./src

# Deploy the application binary into a lean image
FROM debian:bookworm AS release-stage

WORKDIR /

COPY --from=build-stage /go/bin/src /backend
COPY --from=build-stage /root/gocache /root/gocache
COPY --from=build-stage /usr/local/go-faketime /usr/local/go-faketime


# Set the default command to run the backend application.
ENTRYPOINT ["/backend"]

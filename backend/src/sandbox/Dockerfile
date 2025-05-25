# This is the sandbox backend server.
#
# When it's run, the host maps in /var/run/docker.sock to this
# environment so the play-sandbox server can connect to the host's
# docker daemon, which has the gvisor "runsc" runtime available.

FROM golang:1.24 AS build

COPY go.mod /go/src/playground/go.mod
COPY go.sum /go/src/playground/go.sum
WORKDIR /go/src/playground
RUN go mod download

COPY . /go/src/playground
WORKDIR /go/src/playground
RUN go install

FROM debian:bookworm

RUN apt-get update

# Extra stuff for occasional debugging:
RUN apt-get install --yes strace lsof emacs-nox net-tools tcpdump procps

# Install Docker CLI:
# Add Docker's official GPG key:
RUN apt-get update
RUN apt-get install --yes ca-certificates curl
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
RUN chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
RUN echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
           tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get install --yes docker-ce-cli

COPY --from=build /go/bin/sandbox /usr/local/bin/play-sandbox

ENTRYPOINT ["/usr/local/bin/play-sandbox"]

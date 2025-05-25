# Docker environment for the sandbox server itself (containing docker CLI, etc), running
# in a privileged container.
build:
	docker build -f Dockerfile --tag=ahmedakef/gotutor-sandbox .
	docker tag ahmedakef/gotutor-sandbox ahmedakef/gotutor-sandbox:latest

# dockergvisor builds the golang/playground-sandbox-gvisor docker
# image, which is the environment that the untrusted programs run in
# (a busybox:glibc world with this directory's sandbox binary which
# runs in --mode=contained)
dockergvisor:
	docker build -f Dockerfile.gvisor --tag=ahmedakef/gotutor-sandbox-gvisor ..
	docker tag ahmedakef/gotutor-sandbox-gvisor ahmedakef/gotutor-sandbox-gvisor:latest

push: build dockergvisor
	docker push ahmedakef/gotutor-sandbox:latest
	docker push ahmedakef/gotutor-sandbox-gvisor:latest

# runlocal runs the sandbox server locally, for use with the frontend
# parent directory's "test_nacl" or "test_gvisor" test targets.
runlocal: build dockergvisor
	docker network create sandnet || true
	docker kill sandbox_dev || true
	docker run --name=sandbox_dev --rm --network=sandnet -ti -p 127.0.0.1:9090:80/tcp -v /var/run/docker.sock:/var/run/docker.sock ahmedakef/gotutor-sandbox:latest --dev

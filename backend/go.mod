module github.com/ahmedakef/gotutor/backend

go 1.24

toolchain go1.24.0

// replace github.com/ahmedakef/gotutor => ../
// replace github.com/ahmedakef/gotutor/backend/src/sandbox => ./src/sandbox

require (
	github.com/ahmedakef/gotutor v0.0.0-20250531002401-fd4e8b08b7c2
	github.com/ahmedakef/gotutor/backend/src/sandbox v0.0.0-20250531001615-661c960e34ba
	github.com/hashicorp/golang-lru/v2 v2.0.7
	github.com/rs/zerolog v1.34.0
	github.com/stretchr/testify v1.10.0
	github.com/tmc/langchaingo v0.1.12
	go.etcd.io/bbolt v1.4.0
	go.uber.org/atomic v1.11.0
	golang.org/x/mod v0.20.0
	golang.org/x/sync v0.10.0
	golang.org/x/tools v0.14.0
)

require (
	github.com/cilium/ebpf v0.17.1 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/dlclark/regexp2 v1.10.0 // indirect
	github.com/go-delve/delve v1.24.0 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/hashicorp/golang-lru v1.0.2 // indirect
	github.com/mattn/go-colorable v0.1.14 // indirect
	github.com/mattn/go-isatty v0.0.20 // indirect
	github.com/pkoukk/tiktoken-go v0.1.6 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/sirupsen/logrus v1.9.3 // indirect
	golang.org/x/arch v0.13.0 // indirect
	golang.org/x/sys v0.29.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

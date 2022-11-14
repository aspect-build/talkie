module github.com/aspect-build/talkie/examples

go 1.18

require (
	github.com/aspect-build/talkie v0.0.0-00010101000000-000000000000
	github.com/bazelbuild/rules_go v0.34.0
	github.com/golang/mock v1.6.0
	github.com/onsi/ginkgo/v2 v2.1.4
	github.com/onsi/gomega v1.20.0
	google.golang.org/grpc v1.50.1
)

require (
	github.com/golang/protobuf v1.5.2 // indirect
	github.com/google/go-cmp v0.5.9 // indirect
	golang.org/x/net v0.1.0 // indirect
	golang.org/x/sys v0.1.0 // indirect
	golang.org/x/text v0.4.0 // indirect
	google.golang.org/genproto v0.0.0-20221027153422-115e99e71e1c // indirect
	google.golang.org/protobuf v1.28.1 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace github.com/aspect-build/talkie => ../

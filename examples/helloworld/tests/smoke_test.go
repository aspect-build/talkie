// Copyright 2022 Aspect Build Systems, Inc. All rights reserved.
//
// Original authors: Thulio Ferraz Assis (thulio@aspect.dev)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package smoke_test

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"google.golang.org/grpc"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	helloworld "github.com/aspect-build/talkie/examples/helloworld/client"
	pb "github.com/aspect-build/talkie/examples/helloworld/protos"
)

var cmd *exec.Cmd
var port = 50051

var address string

var stdout, stderr strings.Builder

var _ = BeforeSuite(func() {
	server, err := bazel.Runfile("helloworld/helloworld_server_/helloworld_server")
	Expect(err).ToNot(HaveOccurred())

	_, err = os.Stat(server)
	Expect(err).ToNot(HaveOccurred())

	secretsDir := path.Join(os.Getenv("TEST_SRCDIR"), "aspect_talkie_examples", "helloworld", "tests", "testdata", "secrets")

	port++
	address = fmt.Sprintf("127.0.0.1:%d", port)
	cmd = exec.Command(server, "-secrets-dir", secretsDir, "-grpc-address", address)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err = cmd.Start()
	Expect(err).ToNot(HaveOccurred())
})

var _ = AfterSuite(func() {
	err := cmd.Process.Signal(os.Interrupt)
	Expect(err).ToNot(HaveOccurred())

	err = cmd.Wait()
	Expect(err).ToNot(HaveOccurred())

	Expect(stdout.String()).To(BeEmpty())
	stderrStr := stderr.String()
	Expect(stderrStr).To(ContainSubstring("called BeforeStart"))
	Expect(stderrStr).To(ContainSubstring("redis://127.0.0.1:6379"))
	Expect(stderrStr).To(ContainSubstring("called SayHello: John"))
	Expect(stderrStr).To(ContainSubstring("called BeforeExit"))
})

var _ = Describe("Helloworld", func() {
	Describe("Start the server", func() {
		Context("Perform a simple call", func() {
			It("Should reply with a message containing the caller name", func() {
				ctx, cancel := context.WithTimeout(context.Background(), time.Second*5)
				defer cancel()
				greeter := helloworld.NewGreeter(false)
				err := greeter.Connect(ctx, address, grpc.WithBlock())
				Expect(err).ToNot(HaveOccurred())
				defer greeter.Disconnect()
				reply, err := greeter.Client().SayHello(ctx, &pb.HelloRequest{Name: "John"})
				Expect(err).ToNot(HaveOccurred())
				Expect(reply.GetMessage()).To(Equal("Hello John"))
			})
		})
	})
})

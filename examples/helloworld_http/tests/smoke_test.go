// Copyright 2022 Aspect Build Systems Inc.
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
	"bytes"
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/bazelbuild/rules_go/go/tools/bazel"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var cmd *exec.Cmd
var port = 60051

var grpcAddress string
var httpAddress string

var stdout, stderr strings.Builder

var _ = BeforeSuite(func() {
	server, err := bazel.Runfile("helloworld_http/helloworld_http_server_/helloworld_http_server")
	Expect(err).ToNot(HaveOccurred())

	_, err = os.Stat(server)
	Expect(err).ToNot(HaveOccurred())

	port++
	grpcAddress = fmt.Sprintf("127.0.0.1:%d", port)
	port++
	httpAddress = fmt.Sprintf("127.0.0.1:%d", port)
	cmd = exec.Command(server, "-grpc-address", grpcAddress, "-http-address", httpAddress)
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
	Expect(stderrStr).To(ContainSubstring("called SayHello: John"))
	Expect(stderrStr).To(ContainSubstring("called BeforeExit"))
})

var _ = Describe("Helloworld", func() {
	Describe("Start the server", func() {
		Context("Perform a simple HTTP call", func() {
			It("Should reply with a message containing the caller name", func() {
				err := waitForHTTPServer(httpAddress, 50, time.Millisecond*10)
				Expect(err).ToNot(HaveOccurred())
				reqData := bytes.NewBufferString(`{"name":"John"}`)
				resp, err := http.Post(fmt.Sprintf("http://%s/v1/example/say_hello", httpAddress), "application/json", reqData)
				Expect(err).ToNot(HaveOccurred())
				respBody, err := ioutil.ReadAll(resp.Body)
				Expect(err).ToNot(HaveOccurred())
				Expect(string(respBody)).To(Equal(`{"message":"Hello John"}`))
			})
		})
	})
})

func waitForHTTPServer(addr string, retries int, waitBetweenRetries time.Duration) error {
	for i := 0; i < retries; i++ {
		c, err := net.Dial("tcp", addr)
		if err == nil {
			c.Close()
			return nil
		}
		time.Sleep(waitBetweenRetries)
	}
	return fmt.Errorf("failed to wait for http server: maximum number (%d) of retries reached", retries)
}

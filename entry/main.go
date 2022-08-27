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

package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"aspect.build/talkie/entry/render"
	"github.com/emicklei/proto"
)

type stringListFlags []string

func (i *stringListFlags) String() string {
	return strings.Join(*i, ";")
}

func (i *stringListFlags) Set(value string) error {
	*i = append(*i, strings.Split(value, ";")...)
	return nil
}

var clientTemplateFlag string
var serverTemplateFlag string
var clientOutputFlag string
var serverOutputFlag string
var serviceDefinitionFlag string
var serviceProtosFlag stringListFlags
var serviceImplementationFlag string
var enableGrpcGatewayFlag bool
var serviceClientFlag string

func init() {
	flag.StringVar(&clientTemplateFlag, "client_template", "", "The client input template file.")
	flag.StringVar(&serverTemplateFlag, "server_template", "", "The server input template file.")
	flag.StringVar(&clientOutputFlag, "client_output", "", "The client output .go file.")
	flag.StringVar(&serverOutputFlag, "server_output", "", "The server output .go file.")
	flag.StringVar(&serviceDefinitionFlag, "service_definition", "", "The go_library for the gRPC service definition.")
	flag.Var(&serviceProtosFlag, "service_protos", "The .proto files for the gRPC service definition.")
	flag.StringVar(&serviceImplementationFlag, "service_implementation", "", "The go_library for the gRPC service implementation.")
	flag.BoolVar(&enableGrpcGatewayFlag, "enable_grpc_gateway", false, "If a grpc gateway should be created for this service.")
	flag.StringVar(&serviceClientFlag, "service_client", "", "The importpath from the client go_library target.")
	flag.Parse()
}

func main() {
	renderer := render.NewRenderer()
	clientOutput, err := os.Create(clientOutputFlag)
	if err != nil {
		log.Fatal(err)
	}
	defer clientOutput.Close()
	serverOutput, err := os.Create(serverOutputFlag)
	if err != nil {
		log.Fatal(err)
	}
	defer serverOutput.Close()
	services := make([]render.Service, 0)
	for _, proto := range serviceProtosFlag {
		svcs, err := parse(proto)
		if err != nil {
			log.Fatal(err)
		}
		services = append(services, svcs...)
	}
	attrs := render.Attributes{
		Services:              services,
		DefinitionPackage:     serviceDefinitionFlag,
		ImplementationPackage: serviceImplementationFlag,
		EnableGrpcGateway:     enableGrpcGatewayFlag,
		ClientPackage:         serviceClientFlag,
	}
	if err := renderer.Render(clientTemplateFlag, clientOutput, attrs); err != nil {
		log.Fatal(err)
	}
	if err := renderer.Render(serverTemplateFlag, serverOutput, attrs); err != nil {
		log.Fatal(err)
	}
}

func parse(protoFile string) ([]render.Service, error) {
	src, err := os.Open(protoFile)
	if err != nil {
		return nil, fmt.Errorf("failed to parse %q: %w", protoFile, err)
	}
	defer src.Close()

	parser := proto.NewParser(src)
	definition, err := parser.Parse()
	if err != nil {
		return nil, fmt.Errorf("failed to parse %q: %w", protoFile, err)
	}

	pph := &protoParseHandler{
		services: make([]render.Service, 0),
	}
	proto.Walk(
		definition,
		proto.WithService(pph.handleService),
		proto.WithMessage(pph.handleMessage),
	)

	return pph.services, nil
}

type protoParseHandler struct {
	services []render.Service
}

func (pph *protoParseHandler) handleService(s *proto.Service) {
	service := render.Service{
		Name: s.Name,
	}
	pph.services = append(pph.services, service)
}

func (pph *protoParseHandler) handleMessage(m *proto.Message) {
	// TODO: implement.
}

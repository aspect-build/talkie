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
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

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

var outputFlag string
var serviceProtosFlag stringListFlags

func init() {
	flag.StringVar(&outputFlag, "output", "", "The output .json file.")
	flag.Var(&serviceProtosFlag, "service_proto", "The .proto files for the gRPC service definition.")
	flag.Parse()
}

func main() {
	output, err := os.Create(outputFlag)
	if err != nil {
		log.Fatal(err)
	}
	defer output.Close()

	services := make([]Service, 0)
	for _, proto := range serviceProtosFlag {
		svcs, err := parse(proto)
		if err != nil {
			log.Fatal(err)
		}
		services = append(services, svcs...)
	}

	outputStructure := map[string]interface{}{
		"services": services,
	}
	outputData, err := json.Marshal(outputStructure)
	if err != nil {
		log.Fatal(err)
	}

	if err := os.WriteFile(outputFlag, outputData, 0444); err != nil {
		log.Fatal(err)
	}
}

func parse(protoFile string) ([]Service, error) {
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
		services: make([]Service, 0),
	}
	proto.Walk(
		definition,
		proto.WithService(pph.handleService),
	)

	return pph.services, nil
}

type protoParseHandler struct {
	services []Service
}

func (pph *protoParseHandler) handleService(s *proto.Service) {
	service := Service{
		Name: s.Name,
	}
	pph.services = append(pph.services, service)
}

type Service struct {
	Name string
}

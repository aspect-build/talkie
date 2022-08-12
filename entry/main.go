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
	"go/ast"
	"go/parser"
	"go/token"
	"log"
	"os"
	"strings"

	"github.com/aspect-build/talkie/entry/render"
)

type stringListFlags []string

func (i *stringListFlags) String() string {
	return strings.Join(*i, ",")
}

func (i *stringListFlags) Set(value string) error {
	*i = append(*i, value)
	return nil
}

var clientTemplateFlag string
var serverTemplateFlag string
var clientOutputFlag string
var serverOutputFlag string
var serviceDefinitionFlag string
var serviceStubsFlag stringListFlags
var serviceImplementationFlag string

func init() {
	flag.StringVar(&clientTemplateFlag, "client_template", "", "The client input template file.")
	flag.StringVar(&serverTemplateFlag, "server_template", "", "The server input template file.")
	flag.StringVar(&clientOutputFlag, "client_output", "", "The client output .go file.")
	flag.StringVar(&serverOutputFlag, "server_output", "", "The server output .go file.")
	flag.StringVar(&serviceDefinitionFlag, "service_definition", "", "The go_library for the gRPC service definition.")
	flag.Var(&serviceStubsFlag, "service_stubs", "The .pb.go files for the gRPC service definition.")
	flag.StringVar(&serviceImplementationFlag, "service_implementation", "", "The go_library for the gRPC service implementation.")
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
	for _, stub := range serviceStubsFlag {
		svcs, err := parse(stub)
		if err != nil {
			log.Fatal(err)
		}
		services = append(services, svcs...)
	}
	attrs := render.Attributes{
		Services:              services,
		DefinitionPackage:     serviceDefinitionFlag,
		ImplementationPackage: serviceImplementationFlag,
	}
	if err := renderer.Render(clientTemplateFlag, clientOutput, attrs); err != nil {
		log.Fatal(err)
	}
	if err := renderer.Render(serverTemplateFlag, serverOutput, attrs); err != nil {
		log.Fatal(err)
	}
}

func parse(stub string) ([]render.Service, error) {
	fset := token.NewFileSet()

	src, err := os.Open(stub)
	if err != nil {
		return nil, fmt.Errorf("failed to parse %q: %w", stub, err)
	}
	defer src.Close()

	f, err := parser.ParseFile(fset, "", src, parser.AllErrors)
	if err != nil {
		return nil, fmt.Errorf("failed to parse %q: %w", stub, err)
	}

	v := &visitor{
		services: make([]render.Service, 0),
	}
	ast.Walk(v, f)

	return v.services, nil
}

type visitor struct {
	services []render.Service
}

func (v *visitor) Visit(n ast.Node) ast.Visitor {
	if n == nil {
		return nil
	}
	switch decl := n.(type) {
	case *ast.TypeSpec:
		if decl.Name.IsExported() && !strings.HasPrefix(decl.Name.Name, "Unimplemented") && strings.HasSuffix(decl.Name.Name, "Server") {
			serviceName := strings.TrimSuffix(decl.Name.Name, "Server")
			service := render.Service{
				Name: serviceName,
			}
			v.services = append(v.services, service)
		}
	}
	return v
}

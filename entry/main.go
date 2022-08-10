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
	var registerFunctions []string
	for _, stub := range serviceStubsFlag {
		rf, err := parse(stub)
		if err != nil {
			log.Fatal(err)
		}
		registerFunctions = append(registerFunctions, rf...)
	}
	attrs := render.Attributes{
		Service: render.Service{
			Definition:        serviceDefinitionFlag,
			RegisterFunctions: registerFunctions,
			Implementation:    serviceImplementationFlag,
		},
	}
	if err := renderer.Render(clientTemplateFlag, clientOutput, attrs); err != nil {
		log.Fatal(err)
	}
	if err := renderer.Render(serverTemplateFlag, serverOutput, attrs); err != nil {
		log.Fatal(err)
	}
}

func parse(stub string) ([]string, error) {
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
		registerFunctions: make([]string, 0),
	}
	ast.Walk(v, f)

	return v.registerFunctions, nil
}

type visitor struct {
	registerFunctions []string
}

func (v *visitor) Visit(n ast.Node) ast.Visitor {
	if n == nil {
		return nil
	}
	switch decl := n.(type) {
	case *ast.FuncDecl:
		name := decl.Name.String()
		if strings.HasPrefix(name, "Register") &&
			decl.Type.TypeParams == nil &&
			decl.Type.Results == nil &&
			decl.Type.Params != nil {
			v.registerFunctions = append(v.registerFunctions, name)
		}
	}
	return v
}

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
	"io"
	"log"
	"os"
	"path"
	"strings"
	"text/template"

	sprig "github.com/Masterminds/sprig/v3"
	"github.com/imdario/mergo"
)

type stringListFlags []string

func (i *stringListFlags) String() string {
	return strings.Join(*i, ";")
}

func (i *stringListFlags) Set(value string) error {
	*i = append(*i, strings.Split(value, ";")...)
	return nil
}

var templateFlag string
var outputFlag string
var attributesFlag string
var attributesFilesFlag stringListFlags

func init() {
	flag.StringVar(&templateFlag, "template", "", "The input template file.")
	flag.StringVar(&outputFlag, "output", "", "The rendered output file.")
	flag.StringVar(&attributesFlag, "attributes", "", "The attributes JSON string.")
	flag.Var(&attributesFilesFlag, "attributes_file", "An attributes JSON file (can be repeated).")
	flag.Parse()
}

func main() {
	var attributes map[string]interface{}
	if err := json.Unmarshal([]byte(attributesFlag), &attributes); err != nil {
		log.Fatal(err)
	}

	for _, f := range attributesFilesFlag {
		data, err := os.ReadFile(f)
		if err != nil {
			log.Fatal(err)
		}
		var attributesFile map[string]interface{}
		if err := json.Unmarshal(data, &attributesFile); err != nil {
			log.Fatal(err)
		}
		if err := mergo.Merge(&attributes, attributesFile); err != nil {
			log.Fatal(err)
		}
	}

	k8sManifestOutput, err := os.Create(outputFlag)
	if err != nil {
		log.Fatal(err)
	}
	defer k8sManifestOutput.Close()

	renderer := &Renderer{}
	if err := renderer.Render(templateFlag, k8sManifestOutput, attributes); err != nil {
		log.Fatal(err)
	}
}

type Renderer struct{}

// Render renders the template to output using the attributes.
func (*Renderer) Render(
	templateFilename string,
	output io.Writer,
	attrs interface{},
) error {
	tmpl, err := template.
		New(path.Base(templateFilename)).
		Funcs(sprig.HermeticTxtFuncMap()).
		ParseFiles(templateFilename)
	if err != nil {
		return fmt.Errorf("failed to render template: %w", err)
	}
	if err := tmpl.Execute(output, attrs); err != nil {
		return fmt.Errorf("failed to render template: %w", err)
	}
	return nil
}

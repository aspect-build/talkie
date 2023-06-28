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

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path"
	"strings"
	"text/template"

	"dario.cat/mergo"
	sprig "github.com/Masterminds/sprig/v3"
	"sigs.k8s.io/yaml"
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
var templateOpenDelimFlag string
var templateCloseDelimFlag string
var outputFlag string
var attributesFilesFlag stringListFlags
var rungofmtFlag bool
var goBinaryPathFlag string

func init() {
	flag.StringVar(&templateFlag, "template", "", "The input template file.")
	flag.StringVar(&templateOpenDelimFlag, "template_open_delim", "{{", "The opening delimiter for the template rendering.")
	flag.StringVar(&templateCloseDelimFlag, "template_close_delim", "}}", "The closing delimiter for the template rendering.")
	flag.StringVar(&outputFlag, "output", "", "The rendered output file.")
	flag.Var(&attributesFilesFlag, "attributes_file", "An attributes JSON file (can be repeated).")
	flag.BoolVar(&rungofmtFlag, "run_gofmt", false, "Whether gofmt should run on the output or not.")
	flag.StringVar(&goBinaryPathFlag, "go_binary_path", "", "The go binary path (only required when -run_gofmt is set).")
	flag.Parse()
}

func main() {
	var attributes map[string]interface{}

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

	output, err := os.Create(outputFlag)
	if err != nil {
		log.Fatal(err)
	}
	defer output.Close()

	customDelims := delims{
		open:  templateOpenDelimFlag,
		close: templateCloseDelimFlag,
	}

	renderer := &Renderer{}
	if err := renderer.Render(templateFlag, customDelims, output, attributes); err != nil {
		log.Fatal(err)
	}

	if rungofmtFlag {
		for _, subCmd := range []string{"fmt", "fix"} {
			cmd := exec.Command(goBinaryPathFlag, subCmd, outputFlag)
			if err := cmd.Run(); err != nil {
				log.Fatal(err)
			}
		}
	}
}

type Renderer struct{}

// Render renders the template to output using the attributes.
func (*Renderer) Render(
	templateFilename string,
	customDelims delims,
	output io.Writer,
	attrs interface{},
) error {
	tmpl, err := template.New(path.Base(templateFilename)).
		Option("missingkey=error"). // If a key is missing when rendering, return an error.
		Delims(customDelims.open, customDelims.close).
		Funcs(sprig.HermeticTxtFuncMap()).
		Funcs(template.FuncMap{
			"toYaml": func(o interface{}) string {
				b, _ := yaml.Marshal(o)
				return strings.TrimSpace(string(b))
			},
		}).
		ParseFiles(templateFilename)
	if err != nil {
		return fmt.Errorf("failed to render template: %w", err)
	}

	if err := tmpl.Execute(output, attrs); err != nil {
		return fmt.Errorf("failed to render template: %w", err)
	}
	return nil
}

type delims struct {
	open, close string
}

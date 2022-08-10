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

package render

import (
	"fmt"
	"io"
	"text/template"
)

// Renderer renders a template file to the output with the provided attributes.
type Renderer interface {
	Render(
		templateFilename string,
		output io.Writer,
		attrs Attributes,
	) error
}

type renderer struct{}

// NewRenderer creates a new default Renderer.
func NewRenderer() Renderer {
	return &renderer{}
}

// Render renders the template to output using the attributes.
func (*renderer) Render(
	templateFilename string,
	output io.Writer,
	attrs Attributes,
) error {
	tmpl, err := template.ParseFiles(templateFilename)
	if err != nil {
		return fmt.Errorf("failed to render template: %w", err)
	}
	if err := tmpl.Execute(output, attrs); err != nil {
		return fmt.Errorf("failed to render template: %w", err)
	}
	return nil
}

// Attributes is a set of attributes to be made available to the template being
// rendered.
type Attributes struct {
	Service Service
}

// Service is a set of attributes specific to the Talkie service being rendered.
type Service struct {
	Definition        string
	RegisterFunctions []string
	Implementation    string
}

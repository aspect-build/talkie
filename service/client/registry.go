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

package client

import "fmt"

// Registry represents a Talkie client registry that holds an internal set of
// clients to provide to be queries by Talkie services. This internal set is
// populated by the Talkie framework based on service dependency declaration.
type Registry interface {
	Client(name string) (interface{}, error)
}

type registry struct {
	clients map[string]interface{}
}

// NewRegistry constructs a new Registry. The clients must have been initialized.
func NewRegistry(clients map[string]interface{}) Registry {
	return &registry{
		clients: clients,
	}
}

// Client returns a client for a particular service name. An error is returned
// only if the Talkie client is not available in the internal set. It means the
// service dependency was not declared via the Talkie framework.
func (r *registry) Client(name string) (interface{}, error) {
	client, exists := r.clients[name]
	if !exists {
		return nil, fmt.Errorf("%s Service client not available in the registry", name)
	}
	return client, nil
}

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

package service

import "aspect.build/talkie/logger"

// Talkie represents a Talkie service. It requires extra methods in addition to
// the ones defined by the Server interface in the .pb.go stubs.
type Talkie interface {
	BeforeStart() error
	BeforeExit() error
}

// DefaultHooks satisfies the hooks methods from Talkie. It's intended to be
// used by service implementations that don't need any extra logic for hooks.
type DefaultHooks struct{}

// BeforeStart satisfies Talkie.BeforeStart.
func (*DefaultHooks) BeforeStart() error {
	return nil
}

// BeforeExit satisfies Talkie.BeforeExit.
func (*DefaultHooks) BeforeExit() error {
	return nil
}

// Dependencies is the set of mandatory dependencies of a Talkie service. They
// are initialized by the framework and must be present in all services.
type Dependencies struct {
	Log logger.Logger
}

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

package service

import (
	"context"
	"fmt"

	"github.com/aspect-build/talkie/service"
	"github.com/aspect-build/talkie/service/secrets"

	pb "github.com/aspect-build/talkie/examples/helloworld/protos"
)

// Greeter is the service implementation.
type Greeter struct {
	service.Talkie
}

// BeforeStart overrides service.Talkie.BeforeStart. This is not a mandatory
// method, as service.Talkie provides an empty implementation of this.
func (s *Greeter) BeforeStart() error {
	s.Log.Infof("called BeforeStart")
	redisURL, err := secrets.Get("redis.url")
	if err != nil {
		return fmt.Errorf("failed to initialize Greeter: %w", err)
	}
	s.Log.Infof(redisURL)
	return nil
}

// BeforeExit overrides service.Talkie.BeforeExit. This is not a mandatory
// method, as service.Talkie provides an empty implementation of this.
func (s *Greeter) BeforeExit() error {
	s.Log.Infof("called BeforeExit")
	return nil
}

// SayHello implements the gRPC method of same name.
func (s *Greeter) SayHello(ctx context.Context, in *pb.HelloRequest) (*pb.HelloReply, error) {
	s.Log.Infof("called SayHello: %v", in.GetName())
	return &pb.HelloReply{Message: "Hello " + in.GetName()}, nil
}

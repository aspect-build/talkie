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

import (
	"context"

	"github.com/sirupsen/logrus"

	pb "github.com/aspect-build/talkie/examples/helloworld/protos"
)

// New is a mandatory function that is called by the Talkie framework to get a
// gRPC service implementation for the service definition. The signature of this
// function is part of the Talkie API. Any arguments passed to this function is
// initialized by the framework and should never be mutated by the service
// implementation.
func New(logger *logrus.Logger) *Greeter {
	return &Greeter{
		logger: logger,
	}
}

// Greeter is the service implementation.
type Greeter struct {
	logger *logrus.Logger
}

// SayHello implements the gRPC method of same name.
func (s *Greeter) SayHello(ctx context.Context, in *pb.HelloRequest) (*pb.HelloReply, error) {
	s.logger.Printf("Received: %v", in.GetName())
	return &pb.HelloReply{Message: "Hello " + in.GetName()}, nil
}

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

// GENERATED FILE - DO NOT EDIT!

package client

import (
	"context"
	"fmt"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "github.com/aspect-build/talkie/examples/helloworld_http/protos"
)

// Greeter wraps a pb.GreeterClient by offering the
// Connect and Disconnect methods.
type Greeter interface {
	Connect(ctx context.Context, serverAddr string, extraOpts ...grpc.DialOption) error
	Client() pb.GreeterClient
	Disconnect() error
}

// NewGreeter constructs a Greeter.
func NewGreeter() Greeter {
	return &greeter{}
}

type greeter struct {
	conn   *grpc.ClientConn
	client pb.GreeterClient
}

var defaultOptions = []grpc.DialOption{
	// The connection to the server is a blocking call.
	grpc.WithBlock(),
	// TODO(f0rmiga): do proper mTLS.
	grpc.WithTransportCredentials(insecure.NewCredentials()),
}

// Connect connects to the Greeter service.
func (c *greeter) Connect(ctx context.Context, serverAddr string, extraOpts ...grpc.DialOption) error {
	opts := append(defaultOptions, extraOpts...)
	conn, err := grpc.DialContext(ctx, serverAddr, opts...)
	if err != nil {
		return fmt.Errorf("failed to connect to Greeter: %w", err)
	}
	c.client = pb.NewGreeterClient(conn)
	c.conn = conn
	return nil
}

// Client returns the connected client for Greeter.
func (c *greeter) Client() pb.GreeterClient {
	return c.client
}

// Disconnect disconnects the client from the Greeter service.
func (c *greeter) Disconnect() error {
	if err := c.conn.Close(); err != nil {
		return fmt.Errorf("failed to close connection to Greeter: %w", err)
	}
	return nil
}

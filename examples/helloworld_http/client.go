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
)

var defaultOptions = []grpc.DialOption{
	// The connection to the server is a blocking call.
	grpc.WithBlock(),
	// TODO(f0rmiga): do proper mTLS.
	grpc.WithTransportCredentials(insecure.NewCredentials()),
}

// Connect creates a new gRPC client connection. This is a blocking operation,
// so always pass a context with a timeout.
func Connect(ctx context.Context, serverAddr string, extraOpts ...grpc.DialOption) (*grpc.ClientConn, error) {
	opts := append(defaultOptions, extraOpts...)
	conn, err := grpc.DialContext(ctx, serverAddr, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to create new client connection: %w", err)
	}
	return conn, nil
}

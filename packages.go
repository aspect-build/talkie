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

package talkie

import (
	_ "github.com/avast/retry-go/v4"
	_ "github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	_ "github.com/grpc-ecosystem/grpc-health-probe"
	_ "github.com/sirupsen/logrus"
	_ "google.golang.org/grpc"
	_ "helm.sh/helm/v3/cmd/helm"
	_ "sigs.k8s.io/kind"
)

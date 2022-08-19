# Copyright 2022 Aspect Build Systems Inc.
# Original authors: Thulio Ferraz Assis (thulio@aspect.dev)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This module provides the Talkie rules.
"""

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")
load("//entry:defs.bzl", "entrypoints")

def talkie(
        name,
        importpath,
        service_definition,
        service_implementation,
        enable_grpc_gateway = False,
        tags = [],
        visibility = None,
        **kwargs):
    """Wraps all the Talkie targets.

    Args:
        name: The name of the service.
        importpath: The importpath used by the client go_library.
        service_definition: The go_library containing the gRPC service definitions.
        service_implementation: The go_library containing the gRPC service implementation.
        enable_grpc_gateway: Enables gRPC Gateway (http proxy) for the service.
        tags: Forwarded to all wrapped targets.
        visibility: Forwarded to all wrapped targets.
        **kwargs: Forwarded to the client and server targets.
    """

    client_output = name + "_client.go"
    server_output = name + "_server.go"

    entrypoints(
        name = name + "_entrypoints",
        client_output = client_output,
        enable_grpc_gateway = enable_grpc_gateway,
        server_output = server_output,
        service_definition = service_definition,
        service_implementation = service_implementation,
        service_client = importpath,
        tags = tags,
        visibility = ["//visibility:private"],
    )

    deps = []

    if enable_grpc_gateway:
        deps.extend(
            [
                "@com_github_grpc_ecosystem_grpc_gateway_v2//runtime",
                "@org_golang_google_grpc//credentials/insecure",
                ":{}_client".format(name),
            ],
        )

    go_binary(
        name = name + "_server",
        srcs = [server_output],
        deps = [
            "@aspect_talkie//logger",
            "@aspect_talkie//service",
            "@com_github_sirupsen_logrus//:logrus",
            "@org_golang_google_grpc//:grpc",
            service_definition,
            service_implementation,
        ] + deps,
        tags = tags,
        visibility = visibility,
        **kwargs
    )

    go_library(
        name = name + "_client",
        srcs = [client_output],
        deps = [
            "@org_golang_google_grpc//:grpc",
            "@org_golang_google_grpc//credentials/insecure",
            service_definition,
            service_implementation,
        ],
        importpath = importpath,
        tags = tags,
        visibility = visibility,
        **kwargs
    )

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

"""This module provides the rules for rendering the Talkie entrypoints.
"""

load("@io_bazel_rules_go//go:def.bzl", "GoLibrary")

ProtosInfo = provider(
    doc = "Forwards the .pb.go files found by the _get_protos.",
    fields = {"stubs": "The .pb.go files."},
)

def _get_protos_impl(_, ctx):
    if not hasattr(ctx.rule.attr, "embed") or not len(ctx.rule.attr.embed):
        return []
    embed = ctx.rule.attr.embed[0]
    if not hasattr(embed[OutputGroupInfo], "go_generated_srcs"):
        return []
    stubs = embed[OutputGroupInfo].go_generated_srcs
    return [ProtosInfo(stubs = stubs)]

_get_protos = aspect(_get_protos_impl)

def _entrypoints_impl(ctx):
    outputs = [
        ctx.outputs.client_output,
        ctx.outputs.server_output,
    ]

    args = ctx.actions.args()
    args.add("--client_template", ctx.file._client_template.path)
    args.add("--server_template", ctx.file._server_template.path)
    args.add("--client_output", ctx.outputs.client_output.path)
    args.add("--server_output", ctx.outputs.server_output.path)
    args.add("--service_definition", ctx.attr.service_definition[GoLibrary].importpath)
    args.add("--service_implementation", ctx.attr.service_implementation[GoLibrary].importpath)
    args.add("--service_client", ctx.attr.service_client)
    if ctx.attr.enable_grpc_gateway:
        args.add("--enable_grpc_gateway")

    stubs = ctx.attr.service_definition[ProtosInfo].stubs
    args.add_all("--service_stubs", stubs)

    ctx.actions.run(
        inputs = depset([ctx.file._client_template, ctx.file._server_template], transitive = [stubs]),
        outputs = outputs,
        arguments = [args],
        progress_message = "Generating entrypoints for {}".format(ctx.attr.name),
        executable = ctx.executable._entry,
    )

    return [DefaultInfo(files = depset(outputs))]

entrypoints = rule(
    _entrypoints_impl,
    attrs = {
        "service_definition": attr.label(
            aspects = [_get_protos],
            doc = "The go_library for the gRPC service definition.",
            mandatory = True,
            providers = [GoLibrary],
        ),
        "service_implementation": attr.label(
            doc = "The go_library for the gRPC service implementation.",
            mandatory = True,
            providers = [GoLibrary],
        ),
        "service_client": attr.string(
            doc = "The importpath from the go_library target.",
            mandatory = True,
        ),
        "client_output": attr.output(
            doc = "The generated client output .go file.",
            mandatory = True,
        ),
        "server_output": attr.output(
            doc = "The generated server output .go file.",
            mandatory = True,
        ),
        "enable_grpc_gateway": attr.bool(
            doc = "If a grpc gateway should be created for this service",
            mandatory = False,
        ),
        "_client_template": attr.label(
            allow_single_file = True,
            default = Label("//entry:client_tmpl"),
            doc = "The entrypoint template file for the client program.",
        ),
        "_server_template": attr.label(
            allow_single_file = True,
            default = Label("//entry:server_tmpl"),
            doc = "The entrypoint template file for the server program.",
        ),
        "_entry": attr.label(
            cfg = "exec",
            default = Label("//entry"),
            doc = "The program that renders the Talkie server and client entrypoints.",
            executable = True,
        ),
    },
    doc = "Generates the Talkie server and client entrypoints.",
)

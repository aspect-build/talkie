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

load("@aspect_bazel_lib//lib:transitions.bzl", "platform_transition_filegroup")
load("@aspect_bazel_lib//lib:write_source_files.bzl", "write_source_files")
load("@io_bazel_rules_docker//container:bundle.bzl", "container_bundle")
load("@io_bazel_rules_docker//container:image.bzl", "container_image")
load("@io_bazel_rules_go//go:def.bzl", "GoLibrary", "go_binary")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("//generator/renderer:defs.bzl", "render")

def talkie_service(
        name,
        base_image,
        service_definition,
        service_implementation,
        container_repository = "",
        enable_grpc_gateway = False,
        tags = [],
        visibility = None):
    """Wraps all the Talkie service targets.

    Args:
        name: The name of the service.
        base_image: The OCI base image used for the Talkie server.
        service_definition: The go_library containing the gRPC service definitions.
        service_implementation: The go_library containing the gRPC service implementation.
        container_repository: A container repository to prefix the service images.
        enable_grpc_gateway: Enables gRPC Gateway (http proxy) for the service.
        tags: Forwarded to all wrapped targets.
        visibility: Forwarded to all wrapped targets.
    """

    client_output = name + "_generated_client.go"
    server_output = name + "_generated_server.go"

    entrypoints(
        name = name + "_entrypoints",
        client_output = client_output,
        enable_grpc_gateway = enable_grpc_gateway,
        server_output = server_output,
        service_definition = service_definition,
        service_implementation = service_implementation,
        tags = tags,
        visibility = ["//visibility:private"],
    )

    write_source_files(
        name = "write_{}_client".format(name),
        files = {"client.go": client_output},
        visibility = ["//visibility:private"],
    )

    server_deps = [
        "@aspect_talkie//logger",
        "@aspect_talkie//service",
        "@com_github_sirupsen_logrus//:logrus",
        "@org_golang_google_grpc//:grpc",
        service_definition,
        service_implementation,
    ]

    if enable_grpc_gateway:
        server_deps.extend([
            "@com_github_grpc_ecosystem_grpc_gateway_v2//runtime",
            "@org_golang_google_grpc//credentials/insecure",
        ])

    server_binary_target = name + "_server"
    go_binary(
        name = server_binary_target,
        srcs = [server_output],
        deps = server_deps,
        pure = "on",
        static = "on",
        tags = tags,
        visibility = visibility,
    )

    image_targets = []
    for arch in ["aarch64", "x86_64"]:
        transition_target = "{name}_transition_{arch}".format(name = name, arch = arch)
        platform_transition_filegroup(
            name = transition_target,
            srcs = [server_binary_target],
            tags = ["manual"],
            target_platform = "@aspect_talkie//platforms:linux_" + arch,
        )
        transition_tar_target = "{name}_transition_{arch}_tar".format(name = name, arch = arch)
        dumb_init_path = "/usr/local/bin/dumb-init"
        service_binary_path = "/usr/local/bin/" + name
        pkg_tar(
            name = transition_tar_target,
            files = {
                transition_target: service_binary_path,
                "@dumb_init_{}//file".format(arch): dumb_init_path,
            },
            include_runfiles = True,
            strip_prefix = "/",
            tags = ["manual"],
        )
        image_target = "{name}_image_{arch}".format(name = name, arch = arch)
        image_targets.append(image_target)
        container_image(
            name = image_target,
            architecture = arch,
            base = base_image,
            compression = "gzip",
            entrypoint = [dumb_init_path, "--", service_binary_path],
            experimental_tarball_format = "compressed",
            operating_system = "linux",
            tags = ["manual"],
            tars = [transition_tar_target],
            user = "1000",
            visibility = visibility,
        )

    image_alias_target = name + "_alias_image"
    native.alias(
        name = image_alias_target,
        actual = select({
            "@aspect_talkie//platforms/config:macos_aarch64": name + "_image_aarch64",
            "@aspect_talkie//platforms/config:macos_x86_64": name + "_image_x86_64",
            "@aspect_talkie//platforms/config:linux_aarch64": name + "_image_aarch64",
            "@aspect_talkie//platforms/config:linux_x86_64": name + "_image_x86_64",
        }),
    )
    image_target = name + "_image"
    image_name = "{container_repository}{workspace_name}{package}:{tag}".format(
        container_repository = container_repository + "/" if container_repository else "",
        workspace_name = native.repository_name().replace("@", ""),
        package = native.package_name().replace("/", "_"),
        # TODO(f0rmiga): do proper tagging. Read from the Bazel workspace status
        # and also handle when the workspace status is not set for a particular
        # environment. In that case, use latest.
        tag = "latest",
    )
    container_bundle(
        name = image_target,
        images = {image_name: image_alias_target},
    )

    _talkie_service(
        name = name,
        enable_grpc_gateway = enable_grpc_gateway,
        image = image_target + ".tar",
        image_name = image_name,
        server = server_binary_target,
        visibility = visibility,
    )

ProtosInfo = provider(
    doc = "Forwards the .pb.go files found by the _get_protos.",
    fields = {
        "stubs": "The .pb.go files.",
        "protos": "The .proto files.",
    },
)

def _get_protos_impl(target, ctx):
    if ctx.rule.kind == "proto_library" and hasattr(ctx.rule.attr, "srcs"):
        srcs = depset(transitive = [src.files for src in ctx.rule.attr.srcs])
        return _gen_protos_info(parent = None, protos = srcs)
    if ctx.rule.kind == "go_proto_library" and hasattr(ctx.rule.attr, "proto"):
        proto = ctx.rule.attr.proto[0]
        stubs = target[OutputGroupInfo].go_generated_srcs
        return _gen_protos_info(parent = proto, stubs = stubs)
    if ctx.rule.kind == "go_library" and hasattr(ctx.rule.attr, "embed"):
        embed = ctx.rule.attr.embed[0]
        return _gen_protos_info(parent = embed)
    return []

def _gen_protos_info(parent, protos = depset([]), stubs = depset([])):
    parent_protos = parent[ProtosInfo].protos if parent and ProtosInfo in parent else depset([])
    parent_stubs = parent[ProtosInfo].stubs if parent and ProtosInfo in parent else depset([])
    return [ProtosInfo(
        protos = depset(transitive = [protos, parent_protos]),
        stubs = depset(transitive = [stubs, parent_stubs]),
    )]

_get_protos = aspect(
    _get_protos_impl,
    attr_aspects = ["embed", "proto", "srcs"],
)

def _entrypoints_impl(ctx):
    args = ctx.actions.args()

    protos = ctx.attr.service_definition[ProtosInfo].protos
    args.add_all(protos, before_each = "-service_proto")

    services_json = ctx.actions.declare_file("services.json")
    args.add("-output", services_json)
    ctx.actions.run(
        inputs = protos,
        outputs = [services_json],
        arguments = [args],
        executable = ctx.executable._proto_parser,
    )

    attributes = struct(
        enable_grpc_gateway = ctx.attr.enable_grpc_gateway,
        service_definition = ctx.attr.service_definition[GoLibrary].importpath,
        service_implementation = ctx.attr.service_implementation[GoLibrary].importpath,
    )

    render(
        ctx,
        template = ctx.file._client_template,
        output = ctx.outputs.client_output,
        attributes = attributes,
        attributes_files = [services_json],
        run_gofmt = True,
    )
    render(
        ctx,
        template = ctx.file._server_template,
        output = ctx.outputs.server_output,
        attributes = attributes,
        attributes_files = [services_json],
        run_gofmt = True,
    )
    outputs = depset([
        ctx.outputs.client_output,
        ctx.outputs.server_output,
    ])
    return [DefaultInfo(files = outputs)]

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
            default = Label("//generator/entrypoints:client_tmpl"),
            doc = "The entrypoint template file for the client program.",
        ),
        "_go_binary": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = Label("@go_sdk//:bin/go"),
            executable = True,
        ),
        "_proto_parser": attr.label(
            cfg = "exec",
            default = Label("//generator/proto/parser"),
            executable = True,
        ),
        "_renderer": attr.label(
            cfg = "exec",
            default = Label("//generator/renderer"),
            executable = True,
        ),
        "_server_template": attr.label(
            allow_single_file = True,
            default = Label("//generator/entrypoints:server_tmpl"),
            doc = "The entrypoint template file for the server program.",
        ),
    },
    doc = "Generates the Talkie server and client entrypoints.",
)

TalkieServiceInfo = provider(
    doc = "Contains the information needed to consume a Talkie service.",
    fields = {
        "enable_grpc_gateway": "If a grpc gateway should be created for this service",
        "image_name": "The image name (does not include the image repository).",
        "image_tar": "The image tarballs.",
        "service_name": "The service name.",
    },
)

def _talkie_service_impl(ctx):
    if not ctx.attr.name.endswith("_service"):
        fail("By convention, talkie_service targets must have the _service suffix")

    # The DefaultInfo of this rule is the same as the server, so we forward it.
    server_default_info = ctx.attr.server[DefaultInfo]
    executable = ctx.actions.declare_file(ctx.attr.name)
    ctx.actions.symlink(
        is_executable = True,
        output = executable,
        target_file = server_default_info.files_to_run.executable,
    )
    default_info = DefaultInfo(
        executable = executable,
        files = server_default_info.files,
        runfiles = server_default_info.default_runfiles,
    )

    # In addition to the DefaultInfo, return a TalkieServiceInfo that is used by
    # the deployment rules and any other rules that may want more information
    # about this Talkie service.
    talkie_service_info = TalkieServiceInfo(
        enable_grpc_gateway = ctx.attr.enable_grpc_gateway,
        image_name = ctx.attr.image_name,
        image_tar = ctx.file.image,
        service_name = _sanitize_service_name(ctx.attr.name),
    )

    return [
        default_info,
        talkie_service_info,
    ]

def _sanitize_service_name(service_name):
    return service_name.replace("_", "-")

_talkie_service = rule(
    _talkie_service_impl,
    attrs = {
        "enable_grpc_gateway": attr.bool(
            doc = "If a grpc gateway should be created for this service",
            mandatory = False,
        ),
        "image": attr.label(
            allow_single_file = True,
            doc = "The image tarball for the Talkie service.",
            mandatory = True,
        ),
        "image_name": attr.string(
            default = "",
            doc = "The image name.",
            mandatory = False,
        ),
        "server": attr.label(
            doc = "The go_binary for the Talkie server.",
            mandatory = True,
            providers = [GoLibrary],
        ),
    },
    doc = "The Talkie service. The DefaultInfo forwards the server but it also returns the TalkieServiceInfo, used extensively by talkie_deployment.",
    executable = True,
)

def talkie_deployment(name, services, container_registry = "", **kwargs):
    kind_load_images_output = name + "_kind_load_images.sh"

    _talkie_deployment(
        name = name,
        container_registry = container_registry,
        k8s_manifest_output = name + "_deployment.yaml",
        services = services,
        **kwargs
    )

    _kind_load_images(
        name = name + ".kind_load_images",
        container_registry = container_registry,
        kind_load_images_output = kind_load_images_output,
        services = services,
    )

def _talkie_deployment_impl(ctx):
    if not _validate_services(ctx.attr.services):
        fail("Services cannot have duplicated names: {}".format(ctx.attr.services))

    deployment_attributes = _deployment_attributes(ctx.attr.container_registry, ctx.attr.services)
    render(ctx, ctx.file._k8s_manifest_template, ctx.outputs.k8s_manifest_output, deployment_attributes)
    outputs = depset([ctx.outputs.k8s_manifest_output])
    return [DefaultInfo(files = outputs)]

_DEPLOYMENT_ATTRS = {
    "container_registry": attr.string(
        mandatory = False,
        default = "",
        doc = "A container registry server to prefix the service images.",
    ),
    "services": attr.label_list(
        doc = "The Talkie services to deploy.",
        mandatory = True,
        providers = [TalkieServiceInfo],
    ),
    "_renderer": attr.label(
        cfg = "exec",
        default = Label("//generator/renderer"),
        executable = True,
    ),
}

_talkie_deployment = rule(
    _talkie_deployment_impl,
    attrs = dict(dict({
        "k8s_manifest_output": attr.output(
            doc = "The Kubernetes deployment manifest output .yaml file.",
            mandatory = True,
        ),
        "_k8s_manifest_template": attr.label(
            allow_single_file = True,
            default = Label("//generator/deployment:k8s_manifest_tmpl"),
            doc = "The Kubernetes deployment manifest template file used for each Talkie service.",
        ),
    }).items() + _DEPLOYMENT_ATTRS.items()),
)

def _kind_load_images_impl(ctx):
    if not _validate_services(ctx.attr.services):
        fail("Services cannot have duplicated names: {}".format(ctx.attr.services))

    images = []
    for service in ctx.attr.services:
        images.append(service[TalkieServiceInfo].image_tar)

    deployment_attributes = _deployment_attributes(ctx.attr.container_registry, ctx.attr.services)
    kind_attributes = dict({"kind": ctx.executable._kind.short_path})
    attributes = dict(deployment_attributes.items() + kind_attributes.items())
    render(ctx, ctx.file._kind_load_images_template, ctx.outputs.kind_load_images_output, attributes)
    outputs = depset([
        ctx.outputs.kind_load_images_output,
        ctx.executable._kind,
    ] + images)
    return [DefaultInfo(
        executable = ctx.outputs.kind_load_images_output,
        files = outputs,
        runfiles = ctx.runfiles(transitive_files = outputs),
    )]

_kind_load_images = rule(
    _kind_load_images_impl,
    attrs = dict(dict({
        "kind_load_images_output": attr.output(
            doc = "The output .sh script to load images into Kubernetes-in-Docker (kind).",
            mandatory = True,
        ),
        "_kind": attr.label(
            cfg = "exec",
            default = Label("@io_k8s_sigs_kind//:kind"),
            doc = "The Kubernetes-in-Docker (kind) program.",
            executable = True,
        ),
        "_kind_load_images_template": attr.label(
            allow_single_file = True,
            default = Label("//generator/deployment:kind_load_images_tmpl"),
            doc = "The .sh script template file used to load images into Kubernetes-in-Docker (kind).",
        ),
    }).items() + _DEPLOYMENT_ATTRS.items()),
    executable = True,
    doc = "A wrapper to run the script to load images into Kubernetes-in-Docker (kind)",
)

def _validate_services(services):
    unique = {}
    for service in services:
        name = service[TalkieServiceInfo].service_name
        if name in unique:
            return False
        unique[name] = None
    return True

def _deployment_attributes(container_registry, services):
    return dict({
        "container_registry": container_registry,
        "services": [
            struct(
                enable_grpc_gateway = service[TalkieServiceInfo].enable_grpc_gateway,
                image_tar = service[TalkieServiceInfo].image_tar.short_path,
                image_name = service[TalkieServiceInfo].image_name,
                service_name = service[TalkieServiceInfo].service_name,
            )
            for service in services
        ],
    })

# Copyright 2022 Aspect Build Systems, Inc. All rights reserved.
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
load("@bazel_gomock//:gomock.bzl", "gomock")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@io_bazel_rules_docker//container:bundle.bzl", "container_bundle")
load("@io_bazel_rules_docker//container:image.bzl", "container_image")
load("@io_bazel_rules_go//go:def.bzl", "GoLibrary", "go_binary")
load("@rules_pkg//pkg:tar.bzl", "pkg_tar")
load("//generator/renderer:defs.bzl", "render")
load("//generator/json/bazel_stamp:defs.bzl", "bazel_stamp_to_json")

DEFAULT_VERSION_WORKSPACE_STATUS_KEY = "STABLE_TALKIE_RELEASE_VERSION"
SECRETS_MOUNT_PATH = "/var/talkie/secrets"

def talkie_service(
        name,
        base_image,
        service_definition,
        service_implementation,
        secrets = [],
        version_workspace_status_key = DEFAULT_VERSION_WORKSPACE_STATUS_KEY,
        talks_to = [],
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
        secrets: A list of secrets. E.g. 'redis.username' and 'redis.password' would become
        '{"redis":{"username", "password"}}' under Helm values.
        version_workspace_status_key: The key used to extract the release version from the Bazel workspace status.
        talks_to: A list of other talkie_service targets this Talkie service can talk to.
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
        talks_to = talks_to,
        tags = tags,
        visibility = ["//visibility:private"],
    )

    server_deps = [
        "@aspect_talkie//service",
        "@aspect_talkie//service/client",
        "@aspect_talkie//service/logger",
        "@aspect_talkie//service/secrets",
        "@com_github_avast_retry_go_v4//:retry-go",
        "@com_github_sirupsen_logrus//:logrus",
        "@org_golang_google_grpc//:grpc",
        "@org_golang_google_grpc//health",
        "@org_golang_google_grpc//health/grpc_health_v1",
        service_definition,
        service_implementation,
    ] + talks_to

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
        grpc_health_probe_transition_target = "{name}_grpc_health_probe_transition_{arch}".format(name = name, arch = arch)
        platform_transition_filegroup(
            name = grpc_health_probe_transition_target,
            srcs = ["@com_github_grpc_ecosystem_grpc_health_probe//:grpc-health-probe"],
            tags = ["manual"],
            target_platform = "@aspect_talkie//platforms:linux_" + arch,
        )
        grpc_health_probe_path = "/usr/local/bin/grpc-health-probe"
        pkg_tar(
            name = transition_tar_target,
            files = {
                transition_target: service_binary_path,
                "@dumb_init_{}//file".format(arch): dumb_init_path,
                grpc_health_probe_transition_target: grpc_health_probe_path,
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
    image_name = "{container_repository}{workspace_name}{package}".format(
        container_repository = container_repository + "/" if container_repository else "",
        workspace_name = native.repository_name().replace("@", ""),
        package = native.package_name().replace("/", "_"),
    )

    container_bundle(
        name = image_target,
        images = {"%s:{%s}" % (image_name, version_workspace_status_key): image_alias_target},
        stamp = "@io_bazel_rules_docker//stamp:always",
    )

    _talkie_service(
        name = name,
        client_source = client_output,
        enable_grpc_gateway = enable_grpc_gateway,
        image = image_target + ".tar",
        image_name = image_name,
        version_workspace_status_key = version_workspace_status_key,
        secrets = secrets,
        server = server_binary_target,
        talks_to = talks_to,
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

TALKIE_SERVICE_NAME_TAG = "TALKIE_SERVICE_NAME"

def _get_service_name_impl(_, ctx):
    service_name = None
    for tag in ctx.rule.attr.tags:
        parts = tag.split("=")
        if len(parts) == 2 and parts[0] == TALKIE_SERVICE_NAME_TAG:
            service_name = parts[1]
    if not service_name:
        fail("The Talkie client library needs a tag in the format '{}=<service name>'".format(TALKIE_SERVICE_NAME_TAG))

    return [TalkieServiceClientInfo(
        importpath = ctx.rule.attr.importpath,
        service_name = service_name,
    )]

_get_service_name = aspect(_get_service_name_impl)

TalkieServiceClientInfo = provider(
    doc = "Contains the information needed to consume a Talkie service.",
    fields = {
        "importpath": "The importpath for the service client.",
        "service_name": "The service name.",
    },
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
        talks_to = [s[TalkieServiceClientInfo] for s in ctx.attr.talks_to],
    )

    attributes_json = ctx.actions.declare_file("{}_attributes.json".format(ctx.attr.name))
    ctx.actions.write(attributes_json, json.encode(attributes))

    render(
        ctx,
        template = ctx.file._client_template,
        output = ctx.outputs.client_output,
        attributes_files = [services_json, attributes_json],
        run_gofmt = True,
    )
    render(
        ctx,
        template = ctx.file._server_template,
        output = ctx.outputs.server_output,
        attributes_files = [services_json, attributes_json],
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
        "talks_to": attr.label_list(
            aspects = [_get_service_name],
            allow_empty = True,
            doc = "A list of Talkie client targets this service is allowed to communicate.",
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
        "client_source": "The client .go source file for connecting to the service.",
        "enable_grpc_gateway": "If a grpc gateway should be created for this service.",
        "image_name": "The image name (does not include the image repository or image tag).",
        "image_tar": "The image tarballs.",
        "secrets": "A list of secrets. E.g. 'redis.username' and 'redis.password' would become" +
                   "'{\"redis\":{\"username\", \"password\"}}' under Helm values.",
        "service_name": "The service name.",
        "talks_to": "A list of Talkie client targets this service is allowed to communicate.",
        "version_workspace_status_key": "The key used to extract the release version from the Bazel workspace status.",
    },
)

def _talkie_service_impl(ctx):
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

    secrets = sorted(ctx.attr.secrets)

    # In addition to the DefaultInfo, return a TalkieServiceInfo that is used by
    # the deployment rules and any other rules that may want more information
    # about this Talkie service.
    talkie_service_info = TalkieServiceInfo(
        client_source = ctx.file.client_source,
        enable_grpc_gateway = ctx.attr.enable_grpc_gateway,
        image_name = ctx.attr.image_name,
        image_tar = ctx.file.image,
        secrets = struct(
            parsed = _parse_secrets(secrets),
            unparsed = secrets,
        ),
        service_name = ctx.attr.name,
        talks_to = [s[TalkieServiceClientInfo] for s in ctx.attr.talks_to],
        version_workspace_status_key = ctx.attr.version_workspace_status_key,
    )

    return [
        default_info,
        talkie_service_info,
    ]

def _parse_secrets(secrets):
    parsed = {}

    # Secrets must be sorted so that the 'same prefix' validation is correct. If
    # the secrets are not sorted, then 'if index == len(parts)-1:' would always
    # override parts of the secrets mapping. A check could happen there, but
    # tracking which secret it collides becomes hard to be able to feedback the
    # user more accurately.
    for secret in sorted(secrets):
        parts = secret.split(".")
        current = parsed
        for index, part in enumerate(parts):
            if not _validate_secret_part(part):
                fail("the secret '{}' must not be empty and only contain letters, numbers or underscores".format(secret))
            if index == len(parts) - 1:
                current[part] = None
                break
            if not part in current:
                current[part] = {}
            elif current[part] == None:
                fail("could not parse '{}' - the secret '{}' was already set".format(secret, ".".join(parts[:index + 1])))
            current = current[part]
    return parsed

def _validate_secret_part(part):
    if part == "":
        return False
    for c in range(0, len(part)):
        if not part[c] in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_":
            return False
    return True

_talkie_service = rule(
    _talkie_service_impl,
    attrs = {
        "client_source": attr.label(
            allow_single_file = True,
            doc = "The client .go source file for connecting to the service.",
            mandatory = True,
        ),
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
        "version_workspace_status_key": attr.string(
            doc = "The key used to extract the release version from the Bazel workspace status.",
            mandatory = True,
        ),
        "secrets": attr.string_list(
            default = [],
            doc = "A list of secrets. E.g. 'redis.username' and 'redis.password' would become" +
                  "'{\"redis\":{\"username\", \"password\"}}' under Helm values.",
            mandatory = False,
        ),
        "server": attr.label(
            doc = "The go_binary for the Talkie server.",
            mandatory = True,
            providers = [GoLibrary],
        ),
        "talks_to": attr.label_list(
            aspects = [_get_service_name],
            allow_empty = True,
            doc = "A list of Talkie client targets this service is allowed to communicate.",
            mandatory = True,
            providers = [GoLibrary],
        ),
    },
    doc = "The Talkie service. The DefaultInfo forwards the server but it also returns the TalkieServiceInfo, used extensively by talkie_deployment.",
    executable = True,
)

def talkie_client(name, service, **kwargs):
    _talkie_client(
        name = name,
        service = service,
        **kwargs
    )

    write_source_files(
        name = "write_" + name,
        files = {"client.go": name},
        visibility = ["//visibility:private"],
    )

def _talkie_client_impl(ctx):
    files = [ctx.attr.service[TalkieServiceInfo].client_source]
    return [DefaultInfo(files = depset(files))]

_talkie_client = rule(
    _talkie_client_impl,
    attrs = {
        "service": attr.label(
            doc = "The Talkie service to extract the client source.",
            mandatory = True,
            providers = [TalkieServiceInfo],
        ),
    },
    doc = "Forwards the Talkie client source file to the DefaultInfo.",
)

def talkie_client_mock(name, service_definition, interfaces):
    gomock(
        name = "mock_" + name,
        out = "mock_{}_go".format(name),
        interfaces = interfaces,
        library = service_definition,
        package = "mock",
        visibility = ["//visibility:private"],
    )

    write_source_files(
        name = "write_mock_" + name,
        files = {"mock_{}.go".format(name): "mock_" + name},
        visibility = ["//visibility:private"],
    )

def talkie_deployment(
        name,
        services,
        container_registry = "",
        version_workspace_status_key = DEFAULT_VERSION_WORKSPACE_STATUS_KEY,
        visibility = None,
        **kwargs):
    kind_load_images_output = name + "_kind_load_images.sh"

    _talkie_deployment(
        name = name,
        container_registry = container_registry,
        helm_chart_output = name + ".tgz",
        services = services,
        version_workspace_status_key = version_workspace_status_key,
        visibility = visibility,
        **kwargs
    )

    _kind_load_images(
        name = name + ".kind_load_images",
        container_registry = container_registry,
        deployment_name = name,
        kind_load_images_output = kind_load_images_output,
        services = services,
        visibility = visibility,
    )

def _talkie_deployment_impl(ctx):
    if not _validate_services(ctx.attr.services):
        fail("Services cannot have duplicated names: {}".format(ctx.attr.services))

    bazel_stamp_files = [ctx.info_file, ctx.version_file]
    bazel_stamp_json = ctx.actions.declare_file("{}_bazel_stamping.json".format(ctx.attr.name))
    bazel_stamp_to_json(
        ctx,
        bazel_stamp_files = bazel_stamp_files,
        output = bazel_stamp_json,
    )

    deployment_attributes = _deployment_attributes(ctx.attr.name, ctx.attr.container_registry, ctx.attr.services)
    attributes_json = ctx.actions.declare_file("{}_attribues_stamping.json".format(ctx.attr.name))
    ctx.actions.write(attributes_json, json.encode(deployment_attributes))
    attributes_files = [bazel_stamp_json, attributes_json]

    build_chart_root = paths.join("build", "chart", ctx.attr.name)
    rendered_files = _render_helm_chart(ctx, build_chart_root, attributes_files)
    _build_helm_chart_archive(ctx, build_chart_root, rendered_files, bazel_stamp_files)

    outputs = depset([ctx.outputs.helm_chart_output])
    return [DefaultInfo(files = outputs)]

def _render_helm_chart(ctx, build_chart_root, attributes_files):
    tmpl_pkg = ctx.attr._helm_chart_templates.label.package
    tmpl_workspace_root = ctx.attr._helm_chart_templates.label.workspace_root
    rendered_files = []
    for tmpl in ctx.attr._helm_chart_templates.files.to_list():
        rendered_path = paths.join(build_chart_root, paths.relativize(tmpl.path, paths.join(tmpl_workspace_root, tmpl_pkg)))
        output = ctx.actions.declare_file(rendered_path)
        render(
            ctx,
            template = tmpl,
            output = output,
            attributes_files = attributes_files,
            template_open_delim = "<%",
            template_close_delim = "%>",
        )
        rendered_files.append(output)
    return rendered_files

def _build_helm_chart_archive(ctx, build_chart_root, rendered_files, bazel_stamp_files):
    ctx.actions.run_shell(
        command = _build_helm_chart_archive_command.format(
            bazel_stamp_files = " ".join(["'{}'".format(f.path) for f in bazel_stamp_files]),
            build_chart_root = paths.join(ctx.bin_dir.path, paths.dirname(ctx.build_file_path), build_chart_root),
            helm = ctx.executable._helm.path,
            name = ctx.attr.name,
            output = ctx.outputs.helm_chart_output.path,
            version_workspace_status_key = ctx.attr.version_workspace_status_key,
        ),
        execution_requirements = {
            "block-network": "1",
        },
        inputs = depset(rendered_files + bazel_stamp_files),
        outputs = [ctx.outputs.helm_chart_output],
        tools = [ctx.executable._helm],
    )

_build_helm_chart_archive_command = """\
set -o errexit -o nounset -o pipefail

version=$(cat {bazel_stamp_files} | grep '{version_workspace_status_key}' | awk '{{ print $2 }}')
readonly version

readonly chart_output="chart_output"

"{helm}" package "{build_chart_root}" \
    --version=${{version}} \
    --app-version=${{version}} \
    --destination="${{chart_output}}" \
    1> >(grep --invert-match 'Successfully packaged chart') \
    2> >(grep --invert-match 'found symbolic link in path')

mv "${{chart_output}}"/*.tgz "{output}"
"""

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
    "_bazel_stamp_to_json": attr.label(
        cfg = "exec",
        default = Label("//generator/json/bazel_stamp"),
        executable = True,
    ),
}

_talkie_deployment = rule(
    _talkie_deployment_impl,
    attrs = dict(dict({
        "helm_chart_output": attr.output(
            doc = "The Helm chart release tarball.",
            mandatory = True,
        ),
        "version_workspace_status_key": attr.string(
            doc = "The key used to extract the release version from the Bazel workspace status.",
            mandatory = True,
        ),
        "_helm_chart_templates": attr.label(
            default = Label("//generator/deployment/helm/chart"),
            doc = "The Helm chart templates. It's a bit of an inception as there are 2 levels of templates. The final tarball still contains regular Helm templates.",
        ),
        "_helm": attr.label(
            cfg = "exec",
            default = Label("@sh_helm_helm_v3//cmd/helm"),
            executable = True,
        ),
    }).items() + _DEPLOYMENT_ATTRS.items()),
)

def _kind_load_images_impl(ctx):
    if not _validate_services(ctx.attr.services):
        fail("Services cannot have duplicated names: {}".format(ctx.attr.services))

    images = []
    for service in ctx.attr.services:
        images.append(service[TalkieServiceInfo].image_tar)

    deployment_attributes = _deployment_attributes(ctx.attr.deployment_name, ctx.attr.container_registry, ctx.attr.services)
    kind_attributes = dict({"kind": ctx.executable._kind.short_path})
    attributes = dict(deployment_attributes.items() + kind_attributes.items())

    attributes_json = ctx.actions.declare_file("{}_attribues_stamping.json".format(ctx.attr.name))
    ctx.actions.write(attributes_json, json.encode(attributes))

    render(
        ctx,
        template = ctx.file._kind_load_images_template,
        output = ctx.outputs.kind_load_images_output,
        attributes_files = [attributes_json],
    )
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
        "deployment_name": attr.string(
            doc = "The name of the talkie_deployment target.",
            mandatory = True,
        ),
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

def _deployment_attributes(name, container_registry, services):
    return dict({
        "container_registry": container_registry,
        "name": name,
        "secrets_mount_path": SECRETS_MOUNT_PATH,
        "services": [
            struct(
                enable_grpc_gateway = service[TalkieServiceInfo].enable_grpc_gateway,
                image_name = service[TalkieServiceInfo].image_name,
                image_tar = service[TalkieServiceInfo].image_tar.short_path,
                secrets = service[TalkieServiceInfo].secrets,
                service_name = service[TalkieServiceInfo].service_name,
                talks_to = service[TalkieServiceInfo].talks_to,
                version_workspace_status_key = service[TalkieServiceInfo].version_workspace_status_key,
            )
            for service in services
        ],
    })

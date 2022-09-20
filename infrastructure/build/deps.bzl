"""This module contains the infra build dependencies.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")

KUBECTL_VERSION = "1.25.0"

def build_dependencies(kubectl_version = None):
    if not kubectl_version:
        kubectl_version = KUBECTL_VERSION

    _kubectl(kubectl_version)

def _kubectl(version):
    http_file(
        name = "kubectl_macos_aarch64",
        executable = True,
        url = "https://dl.k8s.io/release/v{0}/bin/darwin/arm64/kubectl".format(version),
    )
    http_file(
        name = "kubectl_macos_x86_64",
        executable = True,
        url = "https://dl.k8s.io/release/v{0}/bin/darwin/amd64/kubectl".format(version),
    )
    http_file(
        name = "kubectl_linux_x86_64",
        executable = True,
        url = "https://dl.k8s.io/release/v{0}/bin/linux/amd64/kubectl".format(version),
    )

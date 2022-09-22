"""This module contains the infra build dependencies.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_file")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

def infrastructure_dependencies():
    _dumb_init()
    _kubectl()
    _metallb()

def _dumb_init():
    maybe(
        http_file,
        name = "dumb_init_aarch64",
        downloaded_file_path = "dumb-init",
        executable = True,
        sha256 = "b7d648f97154a99c539b63c55979cd29f005f88430fb383007fe3458340b795e",
        urls = [
            "https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_aarch64",
        ],
    )
    maybe(
        http_file,
        name = "dumb_init_x86_64",
        downloaded_file_path = "dumb-init",
        executable = True,
        sha256 = "e874b55f3279ca41415d290c512a7ba9d08f98041b28ae7c2acb19a545f1c4df",
        urls = [
            "https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64",
        ],
    )

def _kubectl():
    maybe(
        http_file,
        name = "kubectl_macos_aarch64",
        downloaded_file_path = "kubectl",
        executable = True,
        sha256 = "6015dda6e89ee610caefaa26443e92c9529803676b1bf7747211ed7d1f2c8f78",
        url = "https://dl.k8s.io/release/v1.25.0/bin/darwin/arm64/kubectl",
    )
    maybe(
        http_file,
        name = "kubectl_macos_x86_64",
        downloaded_file_path = "kubectl",
        executable = True,
        sha256 = "c17ca54480437d069679d8da8640bca0bd84a5e2614ce9fc7e9c955c4145b768",
        url = "https://dl.k8s.io/release/v1.25.0/bin/darwin/amd64/kubectl",
    )
    maybe(
        http_file,
        name = "kubectl_linux_x86_64",
        downloaded_file_path = "kubectl",
        executable = True,
        sha256 = "e23cc7092218c95c22d8ee36fb9499194a36ac5b5349ca476886b7edc0203885",
        url = "https://dl.k8s.io/release/v1.25.0/bin/linux/amd64/kubectl",
    )

def _metallb():
    maybe(
        http_file,
        name = "metallb_native_manifest",
        downloaded_file_path = "metallb-native.yaml",
        sha256 = "b477af38dd34ab127fbec905ec1db4ff537bfd3c1490b1d6eed833486576808f",
        url = "https://raw.githubusercontent.com/metallb/metallb/v0.13.5/config/manifests/metallb-native.yaml",
    )

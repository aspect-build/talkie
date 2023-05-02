workspace(name = "aspect_talkie")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "com_grail_bazel_toolchain",
    sha256 = "dfe9753f8e687f49de9514634d300fbaa6d68ca1f9a052b44023f640ce6bdffa",
    strip_prefix = "bazel-toolchain-795d76fd03e0b17c0961f0981a8512a00cba4fa2",
    urls = ["https://github.com/grailbio/bazel-toolchain/archive/795d76fd03e0b17c0961f0981a8512a00cba4fa2.tar.gz"],
)

load("@com_grail_bazel_toolchain//toolchain:deps.bzl", "bazel_toolchain_dependencies")

bazel_toolchain_dependencies()

load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "14.0.0",
    sha256 = {
        "darwin-aarch64": "1b8975db6b638b308c1ee437291f44cf8f67a2fb926eb2e6464efd180e843368",
        "linux-x86_64": "564fcbd79c991e93fdf75f262fa7ac6553ec1dd04622f5d7db2a764c5dc7fac6",
    },
    strip_prefix = {
        "darwin-aarch64": "clang+llvm-14.0.0-arm64-apple-darwin",
        "linux-x86_64": "clang+llvm-14.0.0-x86_64-linux-gnu",
    },
    sysroot = {
        "linux-aarch64": "@org_chromium_sysroot_linux_arm64//:sysroot",
        "linux-x86_64": "@org_chromium_sysroot_linux_x86_64//:sysroot",
        "darwin-aarch64": "@sysroot_darwin_universal//:sysroot",
        "darwin-x86_64": "@sysroot_darwin_universal//:sysroot",
    },
    urls = {
        "darwin-aarch64": ["https://github.com/aspect-forks/llvm-project/releases/download/aspect-release-14.0.0/clang+llvm-14.0.0-arm64-apple-darwin.tar.xz"],
        "linux-x86_64": ["https://github.com/aspect-forks/llvm-project/releases/download/aspect-release-14.0.0/clang+llvm-14.0.0-x86_64-linux-gnu.tar.xz"],
    },
)

load("@llvm_toolchain//:toolchains.bzl", "llvm_register_toolchains")

llvm_register_toolchains()

http_archive(
    name = "io_bazel_rules_go",
    sha256 = "19ef30b21eae581177e0028f6f4b1f54c66467017be33d211ab6fc81da01ea4d",
    urls = ["https://github.com/bazelbuild/rules_go/releases/download/v0.38.0/rules_go-v0.38.0.zip"],
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "ecba0f04f96b4960a5b250c8e8eeec42281035970aa8852dda73098274d14a1d",
    urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.29.0/bazel-gazelle-v0.29.0.tar.gz"],
)

load("//:deps.bzl", "go_dependencies", "talkie_dependencies")

talkie_dependencies()

load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

# gazelle:repository_macro deps.bzl%go_dependencies
go_dependencies()

go_rules_dependencies()

go_register_toolchains(version = "1.20.4")

gazelle_dependencies()

load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

rules_proto_dependencies()

rules_proto_toolchains()

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

_SYSROOT_LINUX_BUILD_FILE = """
filegroup(
    name = "sysroot",
    srcs = glob(["*/**"]),
    visibility = ["//visibility:public"],
)
"""

_SYSROOT_DARWIN_BUILD_FILE = """
filegroup(
    name = "sysroot",
    srcs = glob(
        include = ["**"],
        exclude = ["**/*:*"],
    ),
    visibility = ["//visibility:public"],
)
"""

http_archive(
    name = "org_chromium_sysroot_linux_arm64",
    build_file_content = _SYSROOT_LINUX_BUILD_FILE,
    sha256 = "e39b700d8858d18868544c8c84922f6adfa8419f3f42471b92024ba38eff7aca",
    urls = ["https://commondatastorage.googleapis.com/chrome-linux-sysroot/toolchain/2202c161310ffde63729f29d27fe7bb24a0bc540/debian_stretch_arm64_sysroot.tar.xz"],
)

http_archive(
    name = "org_chromium_sysroot_linux_x86_64",
    build_file_content = _SYSROOT_LINUX_BUILD_FILE,
    sha256 = "04b94ba1098b71f8543cb0ba6c36a6ea2890d4d417b04a08b907d96b38a48574",
    urls = ["https://commondatastorage.googleapis.com/chrome-linux-sysroot/toolchain/f5f68713249b52b35db9e08f67184cac392369ab/debian_bullseye_amd64_sysroot.tar.xz"],
)

http_archive(
    name = "sysroot_darwin_universal",
    build_file_content = _SYSROOT_DARWIN_BUILD_FILE,
    # The ruby header has an infinite symlink that we need to remove.
    patch_cmds = ["rm System/Library/Frameworks/Ruby.framework/Versions/Current/Headers/ruby/ruby"],
    sha256 = "71ae00a90be7a8c382179014969cec30d50e6e627570af283fbe52132958daaf",
    strip_prefix = "MacOSX11.3.sdk",
    urls = ["https://aspect-cdn-bucket.s3.us-east-2.amazonaws.com/sysroots/MacOSX11.3.sdk.tar.xz"],
)

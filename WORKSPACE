workspace(name = "aspect_talkie")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "aspect_gcc_toolchain",
    sha256 = "3341394b1376fb96a87ac3ca01c582f7f18e7dc5e16e8cf40880a31dd7ac0e1e",
    strip_prefix = "gcc-toolchain-0.4.2",
    urls = ["https://github.com/aspect-build/gcc-toolchain/archive/refs/tags/0.4.2.tar.gz"],
)

load("@aspect_gcc_toolchain//toolchain:repositories.bzl", "gcc_toolchain_dependencies")

gcc_toolchain_dependencies()

load("@aspect_gcc_toolchain//toolchain:defs.bzl", "ARCHS", "gcc_register_toolchain")

gcc_register_toolchain(
    name = "gcc_toolchain_aarch64",
    target_arch = ARCHS.aarch64,
)

gcc_register_toolchain(
    name = "gcc_toolchain_x86_64",
    target_arch = ARCHS.x86_64,
)

http_archive(
    name = "com_grail_bazel_toolchain",
    patch_args = ["-p1"],
    patches = ["//patches:com_grail_bazel_toolchain.patch"],
    sha256 = "b54aa3b00a64a3dea06d30f0ff423e91bcea43019c5ff1c319f726f1666c3ff2",
    strip_prefix = "bazel-toolchain-2f6e6adf93f4bf34d7bce7ad797f53c82d998ba8",
    urls = ["https://github.com/grailbio/bazel-toolchain/archive/2f6e6adf93f4bf34d7bce7ad797f53c82d998ba8.tar.gz"],
)

load("@com_grail_bazel_toolchain//toolchain:deps.bzl", "bazel_toolchain_dependencies")

bazel_toolchain_dependencies()

load("@com_grail_bazel_toolchain//toolchain:rules.bzl", "llvm_toolchain")

llvm_toolchain(
    name = "llvm_toolchain",
    llvm_version = "14.0.0",
    sha256 = {"darwin-arm64": "1b8975db6b638b308c1ee437291f44cf8f67a2fb926eb2e6464efd180e843368"},
    strip_prefix = {"darwin-arm64": "clang+llvm-14.0.0-arm64-apple-darwin"},
    sysroot = {
        "linux-aarch64": "@sysroot_aarch64//:sysroot",
        "linux-x86_64": "@sysroot_x86_64//:sysroot",
    },
    urls = {"darwin-arm64": ["https://github.com/aspect-build/llvm-project/releases/download/aspect-release-14.0.0/clang+llvm-14.0.0-arm64-apple-darwin.tar.xz"]},
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

go_register_toolchains(version = "1.19.3")

gazelle_dependencies()

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")

rules_proto_dependencies()

rules_proto_toolchains()

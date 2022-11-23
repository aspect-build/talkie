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
    sha256 = "f485c5e084b48e26ce06a21db502aed7a6f0eea1a5782b8b39b655c620350699",
    strip_prefix = "bazel-toolchain-41a62246da792c07204f36ca2e03ffa6b595c5d2",
    urls = ["https://github.com/grailbio/bazel-toolchain/archive/41a62246da792c07204f36ca2e03ffa6b595c5d2.tar.gz"],
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
    sha256 = "ae013bf35bd23234d1dea46b079f1e05ba74ac0321423830119d3e787ec73483",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.36.0/rules_go-v0.36.0.zip",
        "https://github.com/bazelbuild/rules_go/releases/download/v0.36.0/rules_go-v0.36.0.zip",
    ],
)

http_archive(
    name = "bazel_gazelle",
    sha256 = "efbbba6ac1a4fd342d5122cbdfdb82aeb2cf2862e35022c752eaddffada7c3f3",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.27.0/bazel-gazelle-v0.27.0.tar.gz",
        "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.27.0/bazel-gazelle-v0.27.0.tar.gz",
    ],
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

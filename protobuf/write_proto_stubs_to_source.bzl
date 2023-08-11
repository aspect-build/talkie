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

"""This module contains definitions for dealing with stubs in the source tree.
"""

load("@aspect_bazel_lib//lib:copy_to_directory.bzl", "copy_to_directory")
load("@aspect_bazel_lib//lib:directory_path.bzl", "make_directory_path")
load("@aspect_bazel_lib//lib:write_source_files.bzl", "write_source_files")

def write_proto_stubs_to_source(name, target, output_files):
    native.filegroup(
        name = name,
        srcs = [target],
        output_group = "go_generated_srcs",
    )

    copy_to_directory(
        name = name + "_flattened",
        srcs = [name],
        root_paths = ["**"],
    )

    write_source_files(
        name = "write_" + name,
        files = {
            output_file: make_directory_path(output_file + "_directory_path", name + "_flattened", output_file)
            for output_file in output_files
        },
    )

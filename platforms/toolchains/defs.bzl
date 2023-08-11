# Copyright 2022 Aspect Build Systems, Inc. All rights reserved.
#
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

"""This module registers all the LLVM toolchains that we want to use."""

execution_oses = ["macos", "linux"]
execution_cpus = ["aarch64", "x86_64"]
target_oses = ["macos", "linux"]
target_cpus = ["aarch64", "x86_64"]

platforms = [
    struct(exe_os = exe_os, exe_cpu = exe_cpu, tgt_os = tgt_os, tgt_cpu = tgt_cpu)
    for exe_os in execution_oses
    for exe_cpu in execution_cpus
    for tgt_os in target_oses
    for tgt_cpu in target_cpus
]

# buildifier: disable=unnamed-macro
def register_llvm_toolchains():
    for p in platforms:
        native.register_toolchains("//platforms/toolchains:{}_{}_{}_{}_llvm".format(p.exe_os, p.exe_cpu, p.tgt_os, p.tgt_cpu))

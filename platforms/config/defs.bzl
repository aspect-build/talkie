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

"""This module generated the platforms list for the build matrix."""

oses = ["macos", "linux"]
cpus = ["aarch64", "x86_64"]

platforms = [
    struct(os = os, cpu = cpu)
    for os in oses
    for cpu in cpus
]
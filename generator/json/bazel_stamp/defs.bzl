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

"""This module contains the rendering routines for Go text templates.
"""

def bazel_stamp_to_json(ctx, output, bazel_stamp_files):
    """Renders a template.

    Args:
        ctx: an action context.
        output: the output json file with the bazel stamp varaibles file.
        bazel_stamp_files: files that contain bazel stamp variables that should be turned into a json file
    """

    args = ctx.actions.args()
    args.add("-output", output.path)
    args.add_all(bazel_stamp_files, before_each = "-bazel_stamp_files")

    ctx.actions.run(
        inputs = bazel_stamp_files,
        outputs = [output],
        arguments = [args],
        executable = ctx.executable._bazel_stamp_to_json,
    )

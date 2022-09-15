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

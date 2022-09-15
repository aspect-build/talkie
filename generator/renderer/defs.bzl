"""This module contains the rendering routines for Go text templates.
"""

def render(ctx, template, output, attributes_files = [], run_gofmt = False):
    """Renders a template.

    Args:
        ctx: an action context.
        template: the input template file.
        output: the output rendered file.
        attributes_files: an optional list of attributes JSON files.
        run_gofmt: whether gofmt should run on the output or not.
    """
    inputs = [template] + attributes_files
    args = ctx.actions.args()
    args.add("-template", template.path)
    args.add("-output", output.path)
    args.add_all(attributes_files, before_each = "-attributes_file")

    if run_gofmt:
        args.add("-run_gofmt")
        args.add("-go_binary_path", ctx.executable._go_binary.path)
        inputs.append(ctx.executable._go_binary)
    ctx.actions.run(
        inputs = depset(inputs),
        outputs = [output],
        arguments = [args],
        executable = ctx.executable._renderer,
    )

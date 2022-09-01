"""This module contains the rendering routines for Go text templates.
"""

def render(ctx, template, output, attributes, attributes_files = []):
    """Renders a template.

    Args:
        ctx: an action context.
        template: the input template file.
        output: the output rendered file.
        attributes: a type that can be encoded by json.encode().
        attributes_files: an optional list of attributes JSON files.
    """
    args = ctx.actions.args()
    args.add("-template", template.path)
    args.add("-output", output.path)
    args.add("-attributes", json.encode(attributes))
    args.add_all(attributes_files, before_each = "-attributes_file")
    ctx.actions.run(
        inputs = depset([template] + attributes_files),
        outputs = [output],
        arguments = [args],
        executable = ctx.executable._renderer,
    )

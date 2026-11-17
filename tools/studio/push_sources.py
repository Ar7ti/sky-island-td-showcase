"""Writes repository Luau files into the open Studio place without Rojo (Rojo not connected, see
docs/prompts/CreateTower.prompt.md, Appendix J). Creates missing scripts with the class from the sourcemap.

Usage (always run Python isolated):
  rojo sourcemap default.project.json -o <scratch>/sm.json
  python3 -I tools/studio/push_sources.py <scratch>/sm.json <out.luau> <file.luau> [<file.luau> ...]
  python3 -I tools/studio/studio_mcp.py luau <out.luau>

The generated Luau calls ScriptEditorService:UpdateSourceAsync for every file and prints what it changed.
Rojo writes the same code once it is connected again.
"""
import json
import sys


def find(node, path, target, out):
    for child in node.get("children", []):
        here = path + [(child["name"], child["className"])]
        if target in child.get("filePaths", []):
            out.append(here)
        find(child, here, target, out)


def long_string(text):
    level = 5
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[{text}]{eq}]"


def main():
    sourcemap_path, out_path, *files = sys.argv[1:]
    sourcemap = json.load(open(sourcemap_path, encoding="utf-8"))
    lines = [
        'local ScriptEditorService = game:GetService("ScriptEditorService")',
        "local out = {}",
        "local function ensure(path)",
        "\tlocal node = game:GetService(path[1][1])",
        "\tfor i = 2, #path do",
        "\t\tlocal name, class = path[i][1], path[i][2]",
        "\t\tlocal child = nil",
        "\t\tfor _, c in node:GetChildren() do",
        "\t\t\tif c.Name == name and c.ClassName == class then child = c break end",
        "\t\tend",
        "\t\tchild = child or node:FindFirstChild(name)",
        "\t\tif not child then",
        "\t\t\tchild = Instance.new(class)",
        "\t\t\tchild.Name = name",
        "\t\t\tchild.Parent = node",
        "\t\t\ttable.insert(out, 'created ' .. child:GetFullName())",
        "\t\tend",
        "\t\tnode = child",
        "\tend",
        "\treturn node",
        "end",
    ]
    for file in files:
        found = []
        file = file.strip().replace("\\", "/")
        find(sourcemap, [], file, found)
        if not found:
            print("not in sourcemap:", file, file=sys.stderr)
            continue
        path = found[0]
        source = open(file, encoding="utf-8").read()
        path_lua = "{" + ", ".join(f'{{"{n}", "{c}"}}' for n, c in path) + "}"
        lines.append("do")
        lines.append(f"\tlocal s = ensure({path_lua})")
        lines.append(f"\tlocal src = {long_string(source)}")
        lines.append("\tif s.Source ~= src then")
        lines.append("\t\tScriptEditorService:UpdateSourceAsync(s, function() return src end)")
        lines.append("\t\ttable.insert(out, 'updated ' .. s:GetFullName())")
        lines.append("\tend")
        lines.append("end")
    lines.append('return table.concat(out, "\\n")')
    open(out_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("wrote", out_path)


main()

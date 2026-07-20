import sys
with open("src/shells/zigshell-cairo-pango/src/panel.zig", "r") as f:
    lines = f.readlines()
start = -1
end = -1
for i, line in enumerate(lines):
    if "fn versionsUpdate(w: *Widget) void {" in line:
        start = i
    if start != -1 and "fn versionsClick" in line:
        end = i
        break
new_lines = lines[:start] + ["fn versionsUpdate(w: *Widget) void {\n", "    std.mem.copyForwards(u8, &w.net_txt, \"WL:? LC:?\");\n", "}\n\n"] + lines[end:]
with open("src/shells/zigshell-cairo-pango/src/panel.zig", "w") as f:
    f.writelines(new_lines)

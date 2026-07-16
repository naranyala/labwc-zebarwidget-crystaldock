// shared/shellcore.zig — Aggregator module so both shells import shared code
// by a single registered module name (`shellcore`) instead of duplicating
// source files per shell.
//
// Usage in a shell:
//   const damage = @import("shellcore").damage;
//   const toplevel = @import("shellcore").toplevel;
//
// Register the module in build.zig:
//   const shellcore = b.createModule(.{ .root_source_file = b.path("../shared/shellcore.zig"), ... });
//   root_mod.addImport("shellcore", shellcore);

pub const damage = @import("damage.zig");
pub const toplevel = @import("toplevel.zig");
pub const sysread = @import("sysread.zig");

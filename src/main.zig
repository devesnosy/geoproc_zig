const std = @import("std");
const stl_io = @import("stl_io.zig");

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const input_mesh_filepath = args.next() orelse unreachable;
    const tris = try stl_io.read_stl(input_mesh_filepath, std.heap.page_allocator);
    std.debug.print("Num tris: {}\n", .{tris.items.len});
}

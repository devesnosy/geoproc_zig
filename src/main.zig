const std = @import("std");
const stl_io = @import("stl_io.zig");

fn calc_triangles_area_cdf(tris: []const stl_io.TType, allocator: std.mem.Allocator) !std.ArrayList(f32) {
    var result = std.ArrayList(f32).init(allocator);
    try result.ensureUnusedCapacity(tris.len);
    for (tris) |t| {
        const area = 0.5 * t.calc_twice_area();
        result.appendAssumeCapacity(area);
    }
    for (1..result.items.len) |i| {
        result.items[i] += result.items[i - 1];
    }
    const sum = result.getLast();
    for (0..result.items.len) |i| {
        result.items[i] /= sum;
    }
    return result;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = std.process.args();
    _ = args.skip();
    const input_mesh_filepath = args.next() orelse unreachable;
    const tris = try stl_io.read_stl(input_mesh_filepath, allocator);
    defer tris.deinit();

    const cdf = try calc_triangles_area_cdf(tris.items, allocator);
    _ = cdf;
    std.debug.print("Num tris: {}\n", .{tris.items.len});
}

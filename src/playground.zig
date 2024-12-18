const std = @import("std");
const vec = @import("vec.zig");

// pub fn Mat(comptime NRows: usize, comptime NCols: usize) type {
//     return struct {
//         rows: [NRows]v
//     };
// }

pub fn main() !void {
    const Vec3f = vec.Vec(f32, 3, vec.Default_Num_Type_Info);
    const AABB3f = Vec3f.AABB;

    const aabb = AABB3f.init(Vec3f.init(.{ -1, -1, -1 }), Vec3f.init(.{ 1, 1, 1 }));
    const foo = Vec3f.ray_aabb_intersection_predicate(Vec3f.Ray.init(Vec3f.init(.{ 0, 0, 0 }), Vec3f.init(.{ 1, 0, 0 })), aabb);
    std.debug.print("{}\n", .{foo});

    const Mat3x3 = Vec3f.Mat(3);
    const bar: Mat3x3 = .{ .cols = undefined };
    _ = try bar.minor(0, 0);
    _ = bar.row(1);
}

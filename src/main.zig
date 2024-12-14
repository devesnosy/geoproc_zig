const std = @import("std");
const stl_io = @import("stl_io.zig");
const vec = @import("vec.zig");

const PRNG = std.Random.DefaultPrng;
const Point2f = vec.Vec(f32, 2, vec.Default_Ops);

fn uniform_sample_triangle(zeta: Point2f) Point2f {
    const su0 = std.math.sqrt(zeta.x());
    return Point2f.init(.{ 1.0 - su0, zeta.y() * su0 });
}

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

fn upper_bound(comptime T: type, slice: []const T, value: T) usize {
    var start: usize = 0;
    var end = slice.len;
    while (start != end) {
        const middle = start / 2 + end / 2;
        if (value > slice[middle]) {
            start = middle + 1;
        } else {
            end = middle;
        }
    }
    return start;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // TODO: better CLI user experience
    var args = std.process.args();
    _ = args.skip();
    const input_mesh_filepath = args.next().?;
    const num_points = try std.fmt.parseInt(usize, args.next().?, 10);
    const output_filepath = args.next().?;

    const tris = try stl_io.read_stl(input_mesh_filepath, allocator);
    defer tris.deinit();

    const cdf = try calc_triangles_area_cdf(tris.items, allocator);
    var prng = PRNG.init(0);
    const prng_rand = prng.random();

    const cwd = std.fs.cwd();
    const file = try cwd.createFile(output_filepath, .{});
    defer file.close();
    const writer = file.writer();

    try writer.writeAll("ply\n");
    try writer.writeAll("format binary_little_endian 1.0\n");
    try writer.print("element vertex {}\n", .{num_points});
    try writer.writeAll("property float x\n");
    try writer.writeAll("property float y\n");
    try writer.writeAll("property float z\n");
    try writer.writeAll("end_header\n");

    for (0..num_points) |_| {
        // Pick a random triangle
        // https://pbr-book.org/4ed/Monte_Carlo_Integration/Sampling_Using_the_Inversion_Method
        const ti = blk: {
            const zeta = prng_rand.float(f32);
            break :blk upper_bound(f32, cdf.items, zeta);
        };
        // Sample random point in triangle
        // https://pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations#SamplingaTriangle
        const point = blk: {
            const zeta_1 = prng_rand.float(f32);
            const zeta_2 = prng_rand.float(f32);
            const uv = uniform_sample_triangle(Point2f.init(.{ zeta_1, zeta_2 }));
            break :blk tris.items[ti].at(uv.x(), uv.y());
        };
        try writer.writeInt(i32, @bitCast(point.x()), .little);
        try writer.writeInt(i32, @bitCast(point.y()), .little);
        try writer.writeInt(i32, @bitCast(point.z()), .little);
    }
    std.debug.print("Num tris: {}\n", .{tris.items.len});
}

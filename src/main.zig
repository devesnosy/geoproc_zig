const std = @import("std");

// Homogenous Binary Operation Type
pub fn HBOp_Type(comptime T: type) type {
    return fn (T, T) T;
}

// Homogenous Unary Operation Type
pub fn HUOp_Type(comptime T: type) type {
    return fn (T) T;
}

pub fn Ops_Type(comptime T: type) type {
    return struct {
        add: HBOp_Type(T),
        sub: HBOp_Type(T),
        mul: HBOp_Type(T),
        div: HBOp_Type(T),
    };
}

pub fn Default_Ops(comptime T: type) Ops_Type(T) {
    const funcs = struct {
        fn add(a: T, b: T) T {
            return a + b;
        }
        fn sub(a: T, b: T) T {
            return a - b;
        }
        fn mul(a: T, b: T) T {
            return a * b;
        }
        fn div(a: T, b: T) T {
            return a / b;
        }
    };
    return .{
        .add = funcs.add,
        .sub = funcs.sub,
        .mul = funcs.mul,
        .div = funcs.div,
    };
}

// Graphics Vector
pub fn GVec(comptime T: type, comptime N: usize, ops: fn (type) Ops_Type(T)) type {
    return struct {
        const GVec_Type = @This();
        const Ops = ops(T);
        const Cross_Product_Type = switch (N) {
            2 => T,
            3 => GVec_Type,
            else => @compileError("Cross product type is only defined for 2D and 3D vectors"),
        };

        components: [N]T,

        fn init(components: [N]T) GVec_Type {
            return .{ .components = components };
        }
        fn binary_op(self: GVec_Type, other: GVec_Type, op: HBOp_Type(T)) GVec_Type {
            var result = GVec_Type.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i], other.components[i]);
            return result;
        }
        fn unary_op(self: GVec_Type, op: HUOp_Type(T)) GVec_Type {
            var result = GVec_Type.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i]);
            return result;
        }
        fn reduce(self: GVec_Type, op: HBOp_Type(T)) T {
            var result: T = self.components[0];
            for (1..N) |i| result = op(result, self.components[i]);
            return result;
        }
        fn add(self: GVec_Type, other: GVec_Type) GVec_Type {
            return self.binary_op(other, Ops.add);
        }
        fn sub(self: GVec_Type, other: GVec_Type) GVec_Type {
            return self.binary_op(other, Ops.sub);
        }
        fn dot(self: GVec_Type, other: GVec_Type) T {
            return self.binary_op(other, Ops.mul).sum();
        }
        fn x(self: GVec_Type) T {
            if (N >= 1) return self.components[0];
            @compileError("Vec has no x component");
        }
        fn y(self: GVec_Type) T {
            if (N >= 2) return self.components[1];
            @compileError("Vec has no y component");
        }
        fn z(self: GVec_Type) T {
            if (N >= 3) return self.components[2];
            @compileError("Vec has no z component");
        }
        fn cross_2d(self: GVec_Type, other: GVec_Type) T {
            return self.x() * other.y() - self.y() * other.x();
        }
        fn cross_3d(self: GVec_Type, other: GVec_Type) GVec_Type {
            return GVec_Type.init(.{
                self.y() * other.z() - self.z() * other.y(),
                self.z() * other.x() - self.x() * other.z(),
                self.cross_2d(other),
            });
        }
        fn cross(self: GVec_Type, other: GVec_Type) Cross_Product_Type {
            if (Cross_Product_Type == T) return self.cross_2d(other);
            if (Cross_Product_Type == GVec_Type) return self.cross_3d(other);
        }
        fn mul_s(self: GVec_Type, other: T) GVec_Type {
            var result = GVec_Type.init(self.components);
            for (0..N) |i| result.components[i] *= other;
            return result;
        }
        fn div_s(self: GVec_Type, other: T) GVec_Type {
            var result = GVec_Type.init(self.components);
            for (0..N) |i| result.components[i] /= other;
            return result;
        }
        fn sum(self: GVec_Type) T {
            return self.reduce(Ops.add);
        }
        fn calc_len_sq(self: GVec_Type) T {
            return self.dot(self);
        }
        fn calc_len(self: GVec_Type) T {
            return std.math.sqrt(self.calc_len_sq());
        }
        fn calc_normalized(self: GVec_Type) GVec_Type {
            return self.div_s(self.calc_len());
        }
        pub fn format(
            self: GVec_Type,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("{any}", .{self.components});
        }

        const Triangle = struct {
            const Triangle_Type = @This();
            vertices: [3]GVec_Type,

            pub fn init(vertices: [3]GVec_Type) Triangle_Type {
                return .{ .vertices = vertices };
            }
            pub fn a(self: Triangle_Type) GVec_Type {
                return self.vertices[0];
            }
            pub fn b(self: Triangle_Type) GVec_Type {
                return self.vertices[1];
            }
            pub fn c(self: Triangle_Type) GVec_Type {
                return self.vertices[2];
            }
            pub fn calc_normal(self: Triangle_Type) GVec_Type {
                const ab = self.b().sub(self.a());
                const ac = self.c().sub(self.a());
                return ab.cross(ac).calc_normalized();
            }
        };
    };
}

pub fn read_token(reader: std.fs.File.Reader, optional_out: ?*std.ArrayList(u8)) !void {
    if (optional_out) |out| out.clearRetainingCapacity();
    // Skip leading whitespace
    while (true) {
        const char = reader.readByte() catch return;
        if (!std.ascii.isWhitespace(char)) {
            if (optional_out) |out| try out.append(char);
            break;
        }
    }
    // Read token until whitespace
    while (true) {
        const char = reader.readByte() catch return;
        if (std.ascii.isWhitespace(char)) return;
        if (optional_out) |out| try out.append(char);
    }
}

pub fn skip_token(reader: std.fs.File.Reader) !void {
    try read_token(reader, null);
}

pub fn main() !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("suzanne.stl", .{ .mode = .read_only });
    defer file.close();
    const reader = file.reader();
    try reader.skipBytes(80, .{});
    const num_tris: u64 = try reader.readInt(u32, .little);
    const file_size = try file.getEndPos();
    const expected_binary_size = num_tris * 50 + 84;

    const T3D_f32 = GVec(f32, 3, Default_Ops).Triangle;
    const allocator = std.heap.page_allocator;
    var tris = std.ArrayList(T3D_f32).init(allocator);
    defer tris.deinit();

    if (file_size == expected_binary_size) {
        std.debug.print("Binary\n", .{});
        for (0..num_tris) |_| {
            try reader.skipBytes(12, .{}); // Skip normal
            var t = T3D_f32.init(undefined);
            for (0..3) |i| {
                const x: f32 = @bitCast(try reader.readInt(i32, .little));
                const y: f32 = @bitCast(try reader.readInt(i32, .little));
                const z: f32 = @bitCast(try reader.readInt(i32, .little));
                t.vertices[i].components = .{ x, y, z };
            }
            try tris.append(t);
            try reader.skipBytes(2, .{}); // Skip "attribute byte count"
        }
    } else {
        std.debug.print("ASCII\n", .{});
        try file.seekTo(0);

        var token = std.ArrayList(u8).init(allocator);
        defer token.deinit();

        outer: while (true) {
            try read_token(reader, &token);
            if (token.items.len == 0) break :outer;
            if (std.mem.eql(u8, token.items, "facet")) {
                try skip_token(reader); // Expecting "normal"
                for (0..3) |_| try skip_token(reader); // Skip components of 3D normal vector
                try skip_token(reader); // Expecting "outer"
                try skip_token(reader); // Expecting "loop"
                var t = T3D_f32.init(undefined);
                for (0..3) |i| {
                    try skip_token(reader); // Expecting "vertex"

                    try read_token(reader, &token);
                    if (token.items.len == 0) break :outer;
                    const x = try std.fmt.parseFloat(f32, token.items);

                    try read_token(reader, &token);
                    if (token.items.len == 0) break :outer;
                    const y = try std.fmt.parseFloat(f32, token.items);

                    try read_token(reader, &token);
                    if (token.items.len == 0) break :outer;
                    const z = try std.fmt.parseFloat(f32, token.items);

                    t.vertices[i].components = .{ x, y, z };
                }
                try tris.append(t);
                try skip_token(reader); // Expecting "endloop"
                try skip_token(reader); // Expecting "endfacet"
            }
        }
    }
    std.debug.print("Num tris: {}\n", .{tris.items.len});
}

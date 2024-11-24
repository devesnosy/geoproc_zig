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
        components: [N]T,

        const Self = @This();
        const Ops = ops(T);
        const Cross_Product_Type = switch (N) {
            2 => T,
            3 => Self,
            else => @compileError("Cross product type is only defined for 2D and 3D vectors"),
        };

        fn init(components: [N]T) Self {
            return .{ .components = components };
        }
        fn binary_op(self: Self, other: Self, op: HBOp_Type(T)) Self {
            var result = Self.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i], other.components[i]);
            return result;
        }
        fn unary_op(self: Self, op: HUOp_Type(T)) Self {
            var result = Self.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i]);
            return result;
        }
        fn reduce(self: Self, op: HBOp_Type(T)) T {
            var result: T = self.components[0];
            for (1..N) |i| result = op(result, self.components[i]);
            return result;
        }
        fn add(self: Self, other: Self) Self {
            return self.binary_op(other, Ops.add);
        }
        fn sub(self: Self, other: Self) Self {
            return self.binary_op(other, Ops.add);
        }
        fn dot(self: Self, other: Self) T {
            return self.binary_op(other, Ops.mul).sum();
        }
        fn x(self: Self) T {
            if (N >= 1) return self.components[0];
            @compileError("Vec has no x component");
        }
        fn y(self: Self) T {
            if (N >= 2) return self.components[1];
            @compileError("Vec has no y component");
        }
        fn z(self: Self) T {
            if (N >= 3) return self.components[2];
            @compileError("Vec has no z component");
        }
        fn cross_2d(self: Self, other: Self) T {
            return self.x() * other.y() - self.y() * other.x();
        }
        fn cross_3d(self: Self, other: Self) Self {
            return Self.init(.{
                self.y() * other.z() - self.z() * other.y(),
                self.z() * other.x() - self.x() * other.z(),
                self.cross_2d(other),
            });
        }
        fn cross(self: Self, other: Self) Cross_Product_Type {
            if (Cross_Product_Type == T) return self.cross_2d(other);
            if (Cross_Product_Type == Self) return self.cross_3d(other);
        }
        fn mul_s(self: Self, other: T) Self {
            var result = Self.init(self.components);
            for (0..N) |i| result.components[i] *= other;
            return result;
        }
        fn div_s(self: Self, other: T) Self {
            var result = Self.init(self.components);
            for (0..N) |i| result.components[i] /= other;
            return result;
        }
        fn sum(self: Self) T {
            return self.reduce(Ops.add);
        }
        fn calc_len_sq(self: Self) T {
            return self.dot(self);
        }
        fn calc_len(self: Self) T {
            return std.math.sqrt(self.calc_len_sq());
        }
        fn calc_normalized(self: Self) Self {
            return self.div_s(self.calc_len());
        }
        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("{any}", .{self.components});
        }
    };
}

pub fn Triangle3D(comptime T: type, ops: fn (type) Ops_Type(T)) type {
    return struct {
        const Self = @This();
        const GVec_Type = GVec(T, 3, ops);

        vertices: [3]GVec_Type,

        pub fn init(vertices: [3]GVec_Type) Self {
            return .{ .vertices = vertices };
        }

        pub fn a(self: Self) GVec_Type {
            return self.vertices[0];
        }
        pub fn b(self: Self) GVec_Type {
            return self.vertices[1];
        }
        pub fn c(self: Self) GVec_Type {
            return self.vertices[2];
        }
        pub fn calc_normal(self: Self) GVec_Type {
            const ab = self.b().sub(self.a());
            const ac = self.c().sub(self.a());
            return ab.cross(ac).calc_normalized();
        }
    };
}

pub fn main() !void {
    const a = GVec(f32, 3, Default_Ops).init(.{ 1, 2, 3 });
    const b = GVec(f32, 3, Default_Ops).init(.{ 4, 5, 6 });
    const c = GVec(f32, 3, Default_Ops).init(.{ 7, 8, 9 });
    const a_cross_b = a.cross(b);
    const a_dot_b = a.dot(b);
    const a_scaled = a.mul_s(100);

    const t = Triangle3D(f32, Default_Ops).init(.{ a, b, c });
    const n = t.calc_normal();
    std.debug.print("{}\n", .{n});

    std.debug.print("a={}, b={}, axb={}, a.b={}, a_scaled={}\n", .{ a, b, a_cross_b, a_dot_b, a_scaled });

    const cwd = std.fs.cwd();
    const file = try cwd.openFile("suzanne_ascii.stl", .{ .mode = .read_only });
    defer file.close();
    const reader = file.reader();
    try reader.skipBytes(80, .{});
    const num_tris: u64 = try reader.readInt(u32, .little);
    const file_size = try file.getEndPos();
    const expected_binary_size = num_tris * 50 + 84;
    if (file_size == expected_binary_size) {
        std.debug.print("Binary", .{});
    } else {
        std.debug.print("ASCII", .{});
    }
}

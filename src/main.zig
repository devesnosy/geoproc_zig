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
            for (0..N) |i| result[i] = op(self.components[i]);
            return result;
        }
        fn reduce(self: Self, op: HBOp_Type(T)) T {
            var result: T = self.components[0];
            for (1..N) |i| result = op(result, self.components[i]);
            return result;
        }
        fn dot_product(self: Self, other: Self) T {
            return self.binary_op(other, Ops.mul).reduce(Ops.add);
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
        fn cross_product_type() type {
            if (N == 2) return T;
            if (N == 3) return Self;
            @compileError("Cross product type is only defined for 2D and 3D vectors");
        }
        fn cross_product_2d(self: Self, other: Self) T {
            return self.x() * other.y() - self.y() * other.x();
        }
        fn cross_product_3d(self: Self, other: Self) Self {
            return Self.init(.{
                self.y() * other.z() - self.z() * other.y(),
                self.z() * other.x() - self.x() * other.z(),
                self.cross_product_2d(other),
            });
        }
        fn cross_product(self: Self, other: Self) cross_product_type() {
            if (cross_product_type() == T) return self.cross_product_2d(other);
            if (cross_product_type() == Self) return self.cross_product_3d(other);
        }
        fn scale(self: Self, other: T) Self {
            var result = Self.init(self.components);
            for (0..N) |i| result[i] *= other;
            return result;
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

pub fn main() !void {
    const a = GVec(i32, 3, Default_Ops).init(.{ 1, 2, 3 });
    const b = GVec(i32, 3, Default_Ops).init(.{ 4, 5, 6 });
    const a_cross_b = a.cross_product(b);
    const a_dot_b = a.dot_product(b);

    std.debug.print("a={}, b={}, axb={}, a.b={}\n", .{ a, b, a_cross_b, a_dot_b });

    const cwd = std.fs.cwd();
    _ = try cwd.openFile("suzanne.stl", .{ .mode = .read_only });
}

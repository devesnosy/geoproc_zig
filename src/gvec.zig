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
            return Ops.sub(Ops.mul(self.x(), other.y()), Ops.mul(self.y(), other.x()));
        }
        fn cross_3d(self: GVec_Type, other: GVec_Type) GVec_Type {
            return GVec_Type.init(.{
                Ops.sub(Ops.mul(self.y(), other.z()), Ops.mul(self.z(), other.y())),
                Ops.sub(Ops.mul(self.z(), other.x()), Ops.mul(self.x(), other.z())),
                self.cross_2d(other),
            });
        }
        fn cross(self: GVec_Type, other: GVec_Type) Cross_Product_Type {
            if (Cross_Product_Type == T) return self.cross_2d(other);
            if (Cross_Product_Type == GVec_Type) return self.cross_3d(other);
        }
        fn mul_s(self: GVec_Type, other: T) GVec_Type {
            var result = GVec_Type.init(self.components);
            for (0..N) |i| result.components[i] = Ops.mul(result.components[i], other);
            return result;
        }
        fn div_s(self: GVec_Type, other: T) GVec_Type {
            var result = GVec_Type.init(self.components);
            for (0..N) |i| result.components[i] = Ops.div(result.components[i], other);
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

        pub const Triangle = struct {
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

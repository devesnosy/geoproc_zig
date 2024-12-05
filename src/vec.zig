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
pub fn Vec(comptime T: type, comptime N: usize, Ops_Type_Fn: fn (type) Ops_Type(T)) type {
    return struct {
        const VType = @This();
        const OType = Ops_Type_Fn(T);
        const CPType = switch (N) {
            2 => T,
            3 => VType,
            else => @compileError("Cross product type is only defined for 2D and 3D vectors"),
        };

        components: [N]T,

        fn init(components: [N]T) VType {
            return .{ .components = components };
        }
        fn binary_op(self: VType, other: VType, op: HBOp_Type(T)) VType {
            var result = VType.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i], other.components[i]);
            return result;
        }
        fn unary_op(self: VType, op: HUOp_Type(T)) VType {
            var result = VType.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i]);
            return result;
        }
        fn reduce(self: VType, op: HBOp_Type(T)) T {
            var result: T = self.components[0];
            for (1..N) |i| result = op(result, self.components[i]);
            return result;
        }
        fn add(self: VType, other: VType) VType {
            return self.binary_op(other, OType.add);
        }
        fn sub(self: VType, other: VType) VType {
            return self.binary_op(other, OType.sub);
        }
        fn dot(self: VType, other: VType) T {
            return self.binary_op(other, OType.mul).sum();
        }
        fn x(self: VType) T {
            if (N >= 1) return self.components[0];
            @compileError("Vec has no x component");
        }
        fn y(self: VType) T {
            if (N >= 2) return self.components[1];
            @compileError("Vec has no y component");
        }
        fn z(self: VType) T {
            if (N >= 3) return self.components[2];
            @compileError("Vec has no z component");
        }
        fn cross_2d(self: VType, other: VType) T {
            return OType.sub(OType.mul(self.x(), other.y()), OType.mul(self.y(), other.x()));
        }
        fn cross_3d(self: VType, other: VType) VType {
            return VType.init(.{
                OType.sub(OType.mul(self.y(), other.z()), OType.mul(self.z(), other.y())),
                OType.sub(OType.mul(self.z(), other.x()), OType.mul(self.x(), other.z())),
                self.cross_2d(other),
            });
        }
        fn cross(self: VType, other: VType) CPType {
            if (CPType == T) return self.cross_2d(other);
            if (CPType == VType) return self.cross_3d(other);
        }
        fn mul_s(self: VType, other: T) VType {
            var result = VType.init(self.components);
            for (0..N) |i| result.components[i] = OType.mul(result.components[i], other);
            return result;
        }
        fn div_s(self: VType, other: T) VType {
            var result = VType.init(self.components);
            for (0..N) |i| result.components[i] = OType.div(result.components[i], other);
            return result;
        }
        fn sum(self: VType) T {
            return self.reduce(OType.add);
        }
        fn calc_len_sq(self: VType) T {
            return self.dot(self);
        }
        fn calc_len(self: VType) T {
            return std.math.sqrt(self.calc_len_sq());
        }
        fn calc_normalized(self: VType) VType {
            return self.div_s(self.calc_len());
        }
        pub fn format(
            self: VType,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("{any}", .{self.components});
        }

        pub const Triangle = struct {
            const TType = @This();
            vertices: [3]VType,

            pub fn init(vertices: [3]VType) TType {
                return .{ .vertices = vertices };
            }
            pub fn a(self: TType) VType {
                return self.vertices[0];
            }
            pub fn b(self: TType) VType {
                return self.vertices[1];
            }
            pub fn c(self: TType) VType {
                return self.vertices[2];
            }
            pub fn calc_normal(self: TType) VType {
                const ab = self.b().sub(self.a());
                const ac = self.c().sub(self.a());
                return ab.cross(ac).calc_normalized();
            }
        };
    };
}

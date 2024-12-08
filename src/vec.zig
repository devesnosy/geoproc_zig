const std = @import("std");

// Homogenous Binary Operation Type
fn HBOp_Type(comptime T: type) type {
    return fn (T, T) T;
}

// Homogenous Unary Operation Type
fn HUOp_Type(comptime T: type) type {
    return fn (T) T;
}

pub fn IOps_Type(comptime T: type) type {
    return struct {
        add: HBOp_Type(T),
        sub: HBOp_Type(T),
        mul: HBOp_Type(T),
        div: HBOp_Type(T),
    };
}

pub fn Default_Ops(comptime T: type) IOps_Type(T) {
    const funcs = struct {
        pub fn add(a: T, b: T) T {
            return a + b;
        }
        pub fn sub(a: T, b: T) T {
            return a - b;
        }
        pub fn mul(a: T, b: T) T {
            return a * b;
        }
        pub fn div(a: T, b: T) T {
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
pub fn Vec(comptime CType: type, comptime N: usize, Ops_Type_Fn: fn (type) IOps_Type(CType)) type {
    return struct {
        const VType = @This();
        const Ops_Type = Ops_Type_Fn(CType);
        const CPType = switch (N) {
            2 => CType,
            3 => VType,
            else => @compileError("Cross product type is only defined for 2D and 3D vectors"),
        };

        components: [N]CType,

        pub fn init(components: [N]CType) VType {
            return .{ .components = components };
        }
        pub fn binary_op(self: VType, other: VType, op: HBOp_Type(CType)) VType {
            var result = VType.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i], other.components[i]);
            return result;
        }
        pub fn unary_op(self: VType, op: HUOp_Type(CType)) VType {
            var result = VType.init(undefined);
            for (0..N) |i| result.components[i] = op(self.components[i]);
            return result;
        }
        pub fn reduce(self: VType, op: HBOp_Type(CType)) CType {
            var result: CType = self.components[0];
            for (1..N) |i| result = op(result, self.components[i]);
            return result;
        }
        pub fn add(self: VType, other: VType) VType {
            return self.binary_op(other, Ops_Type.add);
        }
        pub fn sub(self: VType, other: VType) VType {
            return self.binary_op(other, Ops_Type.sub);
        }
        pub fn dot(self: VType, other: VType) CType {
            return self.binary_op(other, Ops_Type.mul).sum();
        }
        pub fn x(self: VType) CType {
            if (N >= 1) return self.components[0];
            @compileError("Vec has no x component");
        }
        pub fn y(self: VType) CType {
            if (N >= 2) return self.components[1];
            @compileError("Vec has no y component");
        }
        pub fn z(self: VType) CType {
            if (N >= 3) return self.components[2];
            @compileError("Vec has no z component");
        }
        fn cross_2d(self: VType, other: VType) CType {
            return Ops_Type.sub(Ops_Type.mul(self.x(), other.y()), Ops_Type.mul(self.y(), other.x()));
        }
        fn cross_3d(self: VType, other: VType) VType {
            return VType.init(.{
                Ops_Type.sub(Ops_Type.mul(self.y(), other.z()), Ops_Type.mul(self.z(), other.y())),
                Ops_Type.sub(Ops_Type.mul(self.z(), other.x()), Ops_Type.mul(self.x(), other.z())),
                self.cross_2d(other),
            });
        }
        pub fn cross(self: VType, other: VType) CPType {
            if (CPType == CType) return self.cross_2d(other);
            if (CPType == VType) return self.cross_3d(other);
        }
        pub fn mul_s(self: VType, other: CType) VType {
            var result = VType.init(self.components);
            for (0..N) |i| result.components[i] = Ops_Type.mul(result.components[i], other);
            return result;
        }
        pub fn div_s(self: VType, other: CType) VType {
            var result = VType.init(self.components);
            for (0..N) |i| result.components[i] = Ops_Type.div(result.components[i], other);
            return result;
        }
        pub fn sum(self: VType) CType {
            return self.reduce(Ops_Type.add);
        }
        pub fn calc_len_sq(self: VType) CType {
            return self.dot(self);
        }
        pub fn calc_len(self: VType) CType {
            return std.math.sqrt(self.calc_len_sq());
        }
        pub fn calc_normalized(self: VType) VType {
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
            pub fn calc_twice_area_vec(self: TType) VType {
                const ab = self.b().sub(self.a());
                const ac = self.c().sub(self.a());
                return ab.cross(ac);
            }
            pub fn calc_twice_area(self: TType) CType {
                return self.calc_twice_area_vec().calc_len();
            }
            pub fn calc_normal(self: TType) VType {
                return self.calc_twice_area_vec().calc_normalized();
            }
        };

        pub const Ray = struct {
            const RType = @This();
            origin: VType,
            direction: VType,

            pub fn init(origin: [N]CType, direction: [N]CType) RType {
                return .{
                    .origin = origin,
                    .direction = direction,
                };
            }
        };

        pub const AABB = struct {
            const AABBType = @This();
            min: VType,
            max: VType,

            pub fn init(min: [N]CType, max: [N]CType) AABBType {
                return .{
                    .min = min,
                    .max = max,
                };
            }
        };
    };
}

const std = @import("std");

// Homogenous Binary Operation Type
fn HBOp_Type(comptime T: type) type {
    return fn (T, T) T;
}

// Homogenous Unary Operation Type
fn HUOp_Type(comptime T: type) type {
    return fn (T) T;
}

fn BOP_Type(comptime T: type, comptime O: type) type {
    return fn (T, T) O;
}

pub fn INum_Type_Info(comptime T: type) type {
    return struct {
        const Self = @This();
        add: HBOp_Type(T),
        sub: HBOp_Type(T),
        mul: HBOp_Type(T),
        div: HBOp_Type(T),
        equ: BOP_Type(T, bool),
        gt: BOP_Type(T, bool),
        lt: BOP_Type(T, bool),
        add_neutral: T,
        mul_neutral: T,
        mul_zero: T,
        fn negate(self: Self, value: T) T {
            return self.sub(self.add_neutral, value);
        }
        fn neg_one_to_pos_n(self: Self, n: usize) T {
            if (n & 1) self.negate(self.mul_neutral);
            return self.mul_neutral;
        }
        fn is_mul_zero(self: Self, value: T) bool {
            return self.equ(value, self.mul_zero);
        }
    };
}

pub fn Default_Num_Type_Info(comptime T: type) INum_Type_Info(T) {
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
        pub fn equ(a: T, b: T) bool {
            return a == b;
        }
        pub fn gt(a: T, b: T) bool {
            return a > b;
        }
        pub fn lt(a: T, b: T) bool {
            return a < b;
        }
    };
    return .{
        .add = funcs.add,
        .sub = funcs.sub,
        .mul = funcs.mul,
        .div = funcs.div,
        .equ = funcs.equ,
        .gt = funcs.gt,
        .lt = funcs.lt,
        .add_neutral = 0,
        .mul_neutral = 1,
        .mul_zero = 0,
    };
}

// TODO: we should probably make a "tensor" type? so that it can represent matrices and vectors?
// or just a 2D matrix type so that it can represent vectors and matrices, hmmm
pub fn Vec(comptime Num_Type: type, comptime NRows: usize, Num_Type_Info_Fn: fn (type) INum_Type_Info(Num_Type)) type {
    return struct {
        const VType = @This();
        const NTI = Num_Type_Info_Fn(Num_Type);
        const CPType = switch (NRows) {
            2 => Num_Type,
            3 => VType,
            else => @compileError("Cross product type is only defined for 2D and 3D vectors"),
        };

        components: [NRows]Num_Type,

        fn negate_num(value: Num_Type) Num_Type {
            return NTI.negate(value);
        }
        pub fn negate(self: VType) VType {
            return self.unary_op(negate_num);
        }
        pub fn init(components: [NRows]Num_Type) VType {
            return .{ .components = components };
        }
        pub fn binary_op(self: VType, other: VType, op: HBOp_Type(Num_Type)) VType {
            var result = VType.init(undefined);
            for (0..NRows) |i| result.components[i] = op(self.components[i], other.components[i]);
            return result;
        }
        pub fn unary_op(self: VType, op: HUOp_Type(Num_Type)) VType {
            var result = VType.init(undefined);
            for (0..NRows) |i| result.components[i] = op(self.components[i]);
            return result;
        }
        pub fn reduce(self: VType, op: HBOp_Type(Num_Type)) Num_Type {
            var result: Num_Type = self.components[0];
            for (1..NRows) |i| result = op(result, self.components[i]);
            return result;
        }
        pub fn add(self: VType, other: VType) VType {
            return self.binary_op(other, NTI.add);
        }
        pub fn sub(self: VType, other: VType) VType {
            return self.binary_op(other, NTI.sub);
        }
        pub fn dot(self: VType, other: VType) Num_Type {
            return self.binary_op(other, NTI.mul).sum();
        }
        pub fn x(self: VType) Num_Type {
            if (NRows >= 1) return self.components[0];
            @compileError("Vec has no x component");
        }
        pub fn y(self: VType) Num_Type {
            if (NRows >= 2) return self.components[1];
            @compileError("Vec has no y component");
        }
        pub fn z(self: VType) Num_Type {
            if (NRows >= 3) return self.components[2];
            @compileError("Vec has no z component");
        }
        pub fn at(self: VType, i: usize) Num_Type {
            return self.components[i];
        }
        fn cross_2d(self: VType, other: VType) Num_Type {
            return NTI.sub(NTI.mul(self.x(), other.y()), NTI.mul(self.y(), other.x()));
        }
        fn cross_3d(self: VType, other: VType) VType {
            return VType.init(.{
                NTI.sub(NTI.mul(self.y(), other.z()), NTI.mul(self.z(), other.y())),
                NTI.sub(NTI.mul(self.z(), other.x()), NTI.mul(self.x(), other.z())),
                self.cross_2d(other),
            });
        }
        pub fn cross(self: VType, other: VType) CPType {
            if (CPType == Num_Type) return self.cross_2d(other);
            if (CPType == VType) return self.cross_3d(other);
        }
        pub fn mul_s(self: VType, other: Num_Type) VType {
            var result = VType.init(self.components);
            for (0..NRows) |i| result.components[i] = NTI.mul(result.components[i], other);
            return result;
        }
        pub fn div_s(self: VType, other: Num_Type) VType {
            var result = VType.init(self.components);
            for (0..NRows) |i| result.components[i] = NTI.div(result.components[i], other);
            return result;
        }
        pub fn sum(self: VType) Num_Type {
            return self.reduce(NTI.add);
        }
        pub fn calc_len_sq(self: VType) Num_Type {
            return self.dot(self);
        }
        pub fn calc_len(self: VType) Num_Type {
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
            pub fn ab(self: TType) VType {
                return self.b().sub(self.a());
            }
            pub fn ac(self: TType) VType {
                return self.c().sub(self.a());
            }
            pub fn bc(self: TType) VType {
                return self.c().sub(self.b());
            }
            pub fn at(self: TType, u: Num_Type, v: Num_Type) VType {
                return self.ab().mul_s(u).add(self.ac().mul_s(v)).add(self.a());
            }
            pub fn calc_twice_area_vec(self: TType) VType {
                return self.ab().cross(self.ac());
            }
            pub fn calc_twice_area(self: TType) Num_Type {
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

            pub fn init(origin: VType, direction: VType) RType {
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

            pub fn init(min: VType, max: VType) AABBType {
                return .{
                    .min = min,
                    .max = max,
                };
            }

            pub fn contains(self: AABBType, point: VType) bool {
                for (0..NRows) |i| {
                    if (NTI.gt(point.at(i), self.max.at(i))) return false;
                    if (NTI.lt(point.at(i), self.min.at(i))) return false;
                }
                return true;
            }
        };

        pub fn ray_aabb_intersection_predicate(ray: Ray, aabb: AABB) bool {
            const zero_rdi_check = struct {
                fn f(roi: Num_Type, rdi: Num_Type, bb_min_i: Num_Type, bb_max_i: Num_Type) bool {
                    return NTI.is_mul_zero(rdi) and (NTI.lt(roi, bb_min_i) or NTI.gt(roi, bb_max_i));
                }
            }.f;
            const intersect_1d = struct {
                fn f(roi: Num_Type, rdi: Num_Type, value: Num_Type) Num_Type {
                    return NTI.div(NTI.sub(value, roi), rdi);
                }
            }.f;
            if (NRows == 0) return false;
            if (aabb.contains(ray.origin)) return true;

            const bb_min = aabb.min;
            const bb_max = aabb.max;
            var bb_min_i = bb_min.at(0);
            var bb_max_i = bb_max.at(0);
            const ro = ray.origin;
            const rd = ray.direction;
            var roi = ro.at(0);
            var rdi = rd.at(0);
            if (zero_rdi_check(roi, rdi, bb_min_i, bb_max_i)) return false;

            var max = intersect_1d(roi, rdi, bb_max_i);
            if (NTI.lt(max, NTI.mul_neutral)) return false;
            var min = intersect_1d(roi, rdi, bb_min_i);

            if (NTI.gt(min, max)) return false;

            for (1..NRows) |i| {
                roi = ro.at(i);
                rdi = rd.at(i);
                bb_min_i = bb_min.at(i);
                bb_max_i = bb_max.at(i);
                if (zero_rdi_check(roi, rdi, bb_min_i, bb_max_i)) return false;
                const new_min = intersect_1d(roi, rdi, bb_min_i);
                if (NTI.gt(new_min, max)) return false;
                const new_max = intersect_1d(roi, rdi, bb_max_i);
                if (NTI.lt(new_max, min)) return false;
                if (NTI.lt(new_max, max)) max = new_max;
                if (NTI.gt(new_min, min)) min = new_min;
            }
            return true;
        }

        pub fn Mat(comptime NCols: usize) type {
            if (NRows == 0 or NCols == 0) @compileError("0 size matrix is not supported");
            return struct {
                const Mat_Type = @This();
                const Row_Type = Vec(Num_Type, NCols, Num_Type_Info_Fn);
                const Minor_Type = Vec(Num_Type, NRows - 1, Num_Type_Info_Fn).Mat(NCols - 1);
                const Transposed_Type = Vec(Num_Type, NCols, Num_Type_Info_Fn).Mat(NRows);
                cols: [NCols]VType,

                pub fn transform(self: Mat_Type, v: Row_Type) Row_Type {
                    var result = Row_Type.init(undefined);
                    for (0..NCols) |i| {
                        result.components[i] = self.cols[i].dot(v);
                    }
                    return result;
                }
                pub fn init(cols: [NCols]VType) Mat_Type {
                    return .{ .cols = cols };
                }
                pub fn div(self: Mat_Type, value: Num_Type) Mat_Type {
                    var result = Mat_Type.init(undefined);
                    for (0..NRows) |r| {
                        for (0..NCols) |c| {
                            result = NTI.div(self.at(r, c), value);
                        }
                    }
                    return result;
                }
                pub fn at(self: Mat_Type, r: usize, c: usize) Num_Type {
                    return self.col(c).at(r);
                }
                pub fn col(self: Mat_Type, c: usize) VType {
                    return self.cols[c];
                }
                pub fn row(self: Mat_Type, r: usize) Row_Type {
                    var result = Row_Type.init(undefined);
                    for (0..NCols) |c| {
                        result.components[c] = self.col(c).at(r);
                    }
                    return result;
                }
                const Access_Error = error{Out_Of_Bounds};
                pub fn minor(self: Mat_Type, r: usize, c: usize) !Minor_Type {
                    if (r > NRows or c > NCols) return Access_Error.Out_Of_Bounds;
                    var out_r: usize = 0;
                    var out_c: usize = 0;
                    var result = Minor_Type.init(undefined);
                    for (0..NRows) |in_r| {
                        if (in_r == r) continue;
                        for (0..NCols) |in_c| {
                            if (in_c == c) continue;
                            result.cols[out_c].components[out_r] = self.at(in_r, in_c);
                            out_c += 1;
                        }
                        out_c = 0;
                        out_r += 1;
                    }
                    return result;
                }
                fn calc_det_2x2(self: Mat_Type) Num_Type {
                    if (NRows != 2 or NCols != 2) @compileError("Can only compute determinant for 2x2 matrices for now");
                    const q1 = NTI.mul(self.at(0, 0), self.at(1, 1));
                    const q2 = NTI.mul(self.at(0, 1), self.at(1, 0));
                    return NTI.sub(q1, q2);
                }
                fn calc_det_3x3(self: Mat_Type) Num_Type {
                    const m1 = self.minor(0, 0).calc_det();
                    const m2 = NTI.negate(self.minor(0, 1).calc_det());
                    const m3 = self.minor(0, 2).calc_det();

                    const q1 = NTI.mul(self.at(0, 0), m1);
                    const q2 = NTI.mul(self.at(0, 1), m2);
                    const q3 = NTI.mul(self.at(0, 2), m3);

                    return Row_Type.init(.{ q1, q2, q3 }).sum();
                }
                pub fn calc_det(self: Mat_Type) Num_Type {
                    if (NCols != NRows) @compileError("Can only compute determinant for square matrix");
                    if (NCols == 2 and NRows == 2) return self.calc_det_2x2();
                    if (NCols == 3 and NRows == 3) return self.calc_det_3x3();
                    @compileError("Can only compute determinant for 2x2 and 3x3 matrices");
                }
                pub fn calc_cofactor(self: Mat_Type) Mat_Type {
                    var result = Mat_Type.init(undefined);
                    for (0..NRows) |r| {
                        for (0..NCols) |c| {
                            result.cols[c].components[r] = NTI.mul(NTI.neg_one_to_pos_n(r + c), self.minor(r, c).calc_det());
                        }
                    }
                    return result;
                }
                pub fn transposed(self: Mat_Type) Transposed_Type {
                    var result = Mat_Type.init(undefined);
                    for (0..NRows) |i| result.cols[i] = self.row(i);
                    return result;
                }
                pub fn calc_adjoint(self: Mat_Type) Transposed_Type {
                    return self.calc_cofactor().transposed();
                }
                const Div_Error = error{Div_By_Zero};
                pub fn calc_inverse(self: Mat_Type) !Transposed_Type {
                    const d = self.calc_det();
                    if (NTI.is_mul_zero(d)) return Div_Error.Div_By_Zero;
                    return self.calc_adjoint().div(d);
                }
            };
        }
        const Ray_Triangle_Intersect_Result = struct {
            t: Num_Type,
            u: Num_Type,
            v: Num_Type,
        };
        pub fn ray_triangle_intersection(ray: Ray, triangle: Triangle) !Ray_Triangle_Intersect_Result {
            const mat = Mat(3).init(.{
                ray.direction,
                triangle.ab().negate(),
                triangle.ac().negate(),
            });
            const rhs = triangle.a().sub(ray.origin);
            const result = (try mat.calc_inverse()).transform(rhs);
            return result;
        }
    };
}

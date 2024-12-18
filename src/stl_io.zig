const std = @import("std");
const vec = @import("vec.zig");

pub const TType = vec.Vec(f32, 3, vec.Default_Num_Type_Info).Triangle;

fn read_token(reader: std.fs.File.Reader, optional_out: ?*std.ArrayList(u8)) !void {
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

fn skip_token(reader: std.fs.File.Reader) !void {
    try read_token(reader, null);
}

pub fn read_stl(mesh_filepath: []const u8, allocator: std.mem.Allocator) !std.ArrayList(TType) {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile(mesh_filepath, .{ .mode = .read_only });
    defer file.close();
    const reader = file.reader();
    try reader.skipBytes(80, .{});
    const num_tris: u64 = try reader.readInt(u32, .little);
    const file_size = try file.getEndPos();
    const expected_binary_size = num_tris * 50 + 84;

    var tris = std.ArrayList(TType).init(allocator);

    if (file_size == expected_binary_size) {
        std.debug.print("Binary\n", .{});
        for (0..num_tris) |_| {
            try reader.skipBytes(12, .{}); // Skip normal
            var t = TType.init(undefined);
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
                var t = TType.init(undefined);
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
    return tris;
}

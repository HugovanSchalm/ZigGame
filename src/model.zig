const std = @import("std");
const zgltf = @import("zgltf");
const gl = @import("gl");

pub const Model = struct {
    vao: c_uint,
    n_vertices: c_int,
    n_indices: c_int,
    indexed_rendering: bool,

    pub fn render(self: Model) void {
        gl.BindVertexArray(self.vao);
        if (self.indexed_rendering) {
            gl.DrawElements(gl.TRIANGLES, self.n_indices, gl.UNSIGNED_SHORT, 0);
        } else {
            gl.DrawArrays(gl.TRIANGLES, 0, self.n_vertices);
        }
    }
};

pub fn init(allocator: std.mem.Allocator, gltfPath: [] const u8, binPath: [] const u8) !Model {
    // ===[ Parse files ]===
    const buffer = try std.fs.cwd().readFileAllocOptions(
        allocator,
        gltfPath,
        512_000,
        null,
        4,
        null,
    );
    defer allocator.free(buffer);

    const bin = try std.fs.cwd().readFileAllocOptions(
        allocator,
        binPath,
        512_000,
        null,
        4,
        null
    );
    defer allocator.free(bin);

    var gltf = zgltf.init(allocator);
    defer gltf.deinit();

    var vertices: std.ArrayList(f32) = std.ArrayList(f32).init(allocator);
    var indices: std.ArrayList(u16) = std.ArrayList(u16).init(allocator);

    try gltf.parse(buffer);

    // ===[ Gather Vertices ]===
    const mesh = gltf.data.meshes.items[0];
    for (mesh.primitives.items) |primitive| {
        for (primitive.attributes.items) |attribute| {
            switch (attribute) {
                .position => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    gltf.getDataFromBufferView(f32, &vertices, accessor, bin);
                },
                else => {}
            }
            if (primitive.indices) |indices_index| {
                const accessor = gltf.data.accessors.items[indices_index];
                gltf.getDataFromBufferView(u16, &indices, accessor, bin);
            }
        }
    }

    // ===[ Initialize OpenGL vars ]===
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    gl.BindVertexArray(vao);

    var vbo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(
        gl.ARRAY_BUFFER,
        @intCast(vertices.items.len * @sizeOf(f32)),
        vertices.items.ptr,
        gl.STATIC_DRAW
    );

    const indexed_rendering = indices.items.len > 0 ;
    if (indexed_rendering) {
        var ebo: c_uint = undefined;
        gl.GenBuffers(1, @ptrCast(&ebo));
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
        gl.BufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @intCast(indices.items.len * @sizeOf(u32)),
            indices.items.ptr,
            gl.STATIC_DRAW
        );
    }

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 0, 0);
    gl.EnableVertexAttribArray(0);

    gl.BindVertexArray(0);

    return Model {
        .vao = vao,
        .n_vertices = @intCast(vertices.items.len),
        .n_indices = @intCast(indices.items.len),
        .indexed_rendering = indexed_rendering,
    };
}

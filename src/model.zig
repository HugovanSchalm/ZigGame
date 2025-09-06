const std = @import("std");
const Gltf = @import("zgltf").Gltf;
const gl = @import("gl");
const Shader = @import("shader.zig").Shader;
const sdl = @import("sdl3");
const zm = @import("zm");
const c = @import("c.zig").imports;

const Mesh = struct {
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint = 0,
    n_vertices: c_int,
    n_indices: c_int = 0,
    texture: ?c_uint = 0,
    color: zm.Vec4f,

    fn render(self: Mesh) void {
        if (self.texture) |texture| {
            gl.BindTexture(gl.TEXTURE_2D, texture);
        } else {
            gl.BindTexture(gl.TEXTURE_2D, 0);
        }
        gl.BindVertexArray(self.vao);
        if (self.n_indices > 0) {
            gl.DrawElements(gl.TRIANGLES, self.n_indices, gl.UNSIGNED_SHORT, 0);
        } else {
            gl.DrawArrays(gl.TRIANGLES, 0, self.n_vertices);
        }
    }

    fn deinit(self: *Mesh) void {
        gl.DeleteBuffers(1, @ptrCast(&self.vbo));
        gl.DeleteBuffers(1, @ptrCast(&self.ebo));
        gl.DeleteVertexArrays(1, @ptrCast(&self.vao));
        gl.DeleteTextures(1, @ptrCast(&self.texture));
    }
};

pub const Model = struct {
    allocator: std.mem.Allocator,
    meshes: std.ArrayList(Mesh),
    shader: *const Shader,

    pub fn render(self: Model) void {
        self.shader.use();
        for (self.meshes.items) |mesh| {
            self.shader.setVec4f("meshColor", &mesh.color);
            self.shader.setBool("textured", mesh.texture != null);
            print("{any}\n", .{mesh.texture == null});
            mesh.render();
        }
    }

    pub fn deinit(self: *Model) void {
        var i: usize = 0;
        while (i < self.meshes.items.len) : (i += 1) {
            var mesh = &self.meshes.items[i];
            mesh.deinit();
        }
        self.meshes.deinit(self.allocator);
    }
};

pub fn cube(allocator: std.mem.Allocator, shader: *const Shader) !Model {
    var vertices = [_]f32{
        //POSITIONS                 TEXTURE COORDS       NORMALS
        //FRONT
        -0.5, 0.5,  0.5,            0.0, 1.0, 0.0,      0.0,  1.0,
        0.5,  0.5,  0.5,            1.0, 1.0, 0.0,      0.0,  1.0,
        0.5,  -0.5, 0.5,            1.0, 0.0, 0.0,      0.0,  1.0,
        -0.5, -0.5, 0.5,            0.0, 0.0, 0.0,      0.0,  1.0,
        //BACK
        0.5,  0.5,  -0.5,           0.0, 1.0, 0.0,      0.0,  -1.0,
        -0.5, 0.5,  -0.5,           1.0, 1.0, 0.0,      0.0,  -1.0,
        -0.5, -0.5, -0.5,           1.0, 0.0, 0.0,      0.0,  -1.0,
        0.5,  -0.5, -0.5,           0.0, 0.0, 0.0,      0.0,  -1.0,
        //LEFT
        -0.5, 0.5,  -0.5,           0.0, 1.0, -1.0,     0.0,  0.0,
        -0.5, 0.5,  0.5,            1.0, 1.0, -1.0,     0.0,  0.0,
        -0.5, -0.5, 0.5,            1.0, 0.0, -1.0,     0.0,  0.0,
        -0.5, -0.5, -0.5,           0.0, 0.0, -1.0,     0.0,  0.0,
        //RIGHT
        0.5,  0.5,  0.5,            0.0, 1.0, 1.0,      0.0,  0.0,
        0.5,  0.5,  -0.5,           1.0, 1.0, 1.0,      0.0,  0.0,
        0.5,  -0.5, -0.5,           1.0, 0.0, 1.0,      0.0,  0.0,
        0.5,  -0.5, 0.5,            0.0, 0.0, 1.0,      0.0,  0.0,
        //TOP
        -0.5, 0.5,  -0.5,           0.0, 1.0, 0.0,      1.0,  0.0,
        0.5,  0.5,  -0.5,           1.0, 1.0, 0.0,      1.0,  0.0,
        0.5,  0.5,  0.5,            1.0, 0.0, 0.0,      1.0,  0.0,
        -0.5, 0.5,  0.5,            0.0, 0.0, 0.0,      1.0,  0.0,
        //BOTTOM
        0.5,  0.5,  -0.5,           0.0, 1.0, 0.0,      -1.0, 0.0,
        -0.5, 0.5,  0.5,            1.0, 1.0, 0.0,      -1.0, 0.0,
        -0.5, 0.5,  0.5,            1.0, 0.0, 0.0,      -1.0, 0.0,
        0.5,  0.5,  -0.5,           0.0, 0.0, 0.0,      -1.0, 0.0,
    };

    var indices = [_]u16{
        //      FRONT
        0,  1,  2,
        0,  2,  3,
        //      BACK
        4,  5,  6,
        4,  6,  7,
        //      LEFT
        8,  9,  10,
        8,  10, 11,
        //      RIGHT
        12, 13, 14,
        12, 14, 15,
        //      TOP
        16, 17, 18,
        16, 18, 19,
        //      BOTTOM
        20, 21, 22,
        20, 22, 23,
    };

    const vao = generateAndBindVAO();
    const vbo = generateAndBindVBO(&vertices);
    const ebo = generateAndBindEBO(&indices);
    generateVertexAttribs();

    gl.BindVertexArray(0);

    var meshes = try std.ArrayList(Mesh).initCapacity(allocator, 1);
    try meshes.append(allocator, .{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .n_vertices = vertices.len,
        .n_indices = indices.len,
        .color = .{ 1.0, 1.0, 1.0, 1.0 }
    });

    return Model{
        .allocator = allocator,
        .meshes = meshes,
        .shader = shader,
    };
}

pub fn fromGltf(allocator: std.mem.Allocator, gltfPath: []const u8, binPath: []const u8, shader: *const Shader) !Model {
    // ===[ Parse files ]===
    const buffer = try std.fs.cwd().readFileAllocOptions(
        allocator,
        gltfPath,
        2048_000_000,
        null,
        std.mem.Alignment.@"4",
        null,
    );
    defer allocator.free(buffer);

    const bin = try std.fs.cwd().readFileAllocOptions(allocator, binPath, 512_000, null, std.mem.Alignment.@"4", null);
    defer allocator.free(bin);

    var gltf = Gltf.init(allocator);
    defer gltf.deinit();

    try gltf.parse(buffer);

    var meshes = std.ArrayList(Mesh){};

    // ===[ Gather Vertices ]===
    for (gltf.data.nodes) |node| {
        print("{any}\n", .{node});
        const dirPath = std.fs.path.dirname(gltfPath).?;
        const parsedMesh = try parseNode(
            allocator,
            node,
            gltf,
            bin,
            dirPath,
        );
        try meshes.append(allocator, parsedMesh);
    }

    return Model{
        .allocator = allocator,
        .meshes = meshes,
        .shader = shader,
    };
}

fn print(comptime fmt: []const u8, args: anytype) void {
    var buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;
    stdout.print(fmt, args) catch {};
    stdout.flush() catch {};
}

pub fn fromGlb(allocator: std.mem.Allocator, glbPath: []const u8, shader: *const Shader) !Model {
    const buffer = try std.fs.cwd().readFileAllocOptions(
        allocator,
        glbPath,
        2048_000_000,
        null,
        std.mem.Alignment.@"4",
        null,
    );
    defer allocator.free(buffer);

    var gltf = Gltf.init(allocator);
    defer gltf.deinit();

    try gltf.parse(buffer);

    var meshes = std.ArrayList(Mesh){};

    // ===[ Gather Vertices ]===
    for (gltf.data.nodes) |node| {
        const dirPath = std.fs.path.dirname(glbPath).?;
        const parsedMesh = try parseNode(
            allocator,
            node,
            gltf,
            gltf.glb_binary.?,
            dirPath,
        );
        try meshes.append(allocator, parsedMesh);
    }

    return Model{
        .allocator = allocator,
        .meshes = meshes,
        .shader = shader,
    };
}

fn parseNode(allocator: std.mem.Allocator, node: Gltf.Node, gltf: Gltf, bin: []const u8, meshPath: []const u8) !Mesh {
    const mesh = gltf.data.meshes[node.mesh.?];
    // ===[ Initialization ]===
    var vertexpositions: std.ArrayList(f32) = .{};
    defer vertexpositions.deinit(allocator);

    var texcoords: std.ArrayList(f32) = .{};
    defer texcoords.deinit(allocator);

    var normals: std.ArrayList(f32) = .{};
    defer normals.deinit(allocator);

    var indices: std.ArrayList(u16) = .{};
    defer indices.deinit(allocator);

    var texture: ?c_uint = null;

    var meshColor: zm.Vec4f = .{ 1.0, 1.0, 1.0, 1.0 };

    // ===[ Parse all primitives ]===
    for (mesh.primitives) |primitive| {
        for (primitive.attributes) |attribute| {
            switch (attribute) {
                .position => |accessor_index| {
                    const accessor = gltf.data.accessors[accessor_index];
                    gltf.getDataFromBufferView(f32, &vertexpositions, allocator, accessor, bin);
                },
                .texcoord => |accessor_index| {
                    const accessor = gltf.data.accessors[accessor_index];
                    gltf.getDataFromBufferView(f32, &texcoords, allocator, accessor, bin);
                },
                .normal => |normal_index| {
                    const accessor = gltf.data.accessors[normal_index];
                    gltf.getDataFromBufferView(f32, &normals, allocator, accessor, bin);
                },
                else => {},
            }
        }
        if (primitive.indices) |indices_index| {
            const accessor = gltf.data.accessors[indices_index];
            gltf.getDataFromBufferView(u16, &indices, allocator, accessor, bin);
        }
        if (primitive.material) |material_index| {
            const material = gltf.data.materials[material_index];
            meshColor = material.metallic_roughness.base_color_factor;
            if (material.metallic_roughness.base_color_texture) |base_color_texture| {
                const texture_index = base_color_texture.index;
                const source_index = gltf.data.textures[texture_index].source.?;
                const imageInfo = gltf.data.images[source_index];
                if (imageInfo.uri) |uri| {
                    const texturePath = try std.fs.path.joinZ(allocator, &[_][]const u8{ meshPath, uri });
                    defer allocator.free(texturePath);
                    var image = try sdl.image.loadFile(texturePath);
                    defer image.deinit();
                    image = try image.convertFormat(.array_rgb_24);
                    const width: c_int = @intCast(image.getWidth());
                    const height: c_int = @intCast(image.getHeight());
                    texture = createTexture(width, height, image.getPixels().?);
                } else {
                    const imageData = imageInfo.data.?;
                    const stream = try sdl.io_stream.Stream.initFromConstMem(imageData);
                    defer stream.deinit() catch {};
                    const image = try sdl.image.loadPngIo(stream);
                    defer image.deinit();
                    texture = createTexture(@intCast(image.getWidth()), @intCast(image.getHeight()), image.getPixels().?);
                }
            }
        }
    }

    // ===[ Combine into final vertex array ]===
    var vertices = try std.ArrayList(f32).initCapacity(allocator, vertexpositions.items.len / 3);
    defer vertices.deinit(allocator);

    for (0..vertexpositions.items.len / 3) |index| {
        try vertices.appendSlice(allocator, vertexpositions.items[3 * index .. 3 * index + 3]);
        try vertices.appendSlice(allocator, texcoords.items[2 * index .. 2 * index + 2]);
        try vertices.appendSlice(allocator, normals.items[3 * index .. 3 * index + 3]);
    }

    // ===[ Initialize OpenGL vars ]===
    const vao = generateAndBindVAO();
    const vbo = generateAndBindVBO(vertices.items);
    const ebo = generateAndBindEBO(indices.items);

    generateVertexAttribs();

    gl.BindVertexArray(0);

    return Mesh{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .n_vertices = @intCast(vertexpositions.items.len / 3),
        .n_indices = @intCast(indices.items.len),
        .texture = texture,
        .color = meshColor,
    };
}

fn generateVertexAttribs() void {
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 5 * @sizeOf(f32));
    gl.EnableVertexAttribArray(2);
}

fn generateAndBindVAO() c_uint {
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    gl.BindVertexArray(vao);

    return vao;
}

fn generateAndBindVBO(vertices: []f32) c_uint {
    var vbo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(vertices.len * @sizeOf(f32)), vertices.ptr, gl.STATIC_DRAW);

    return vbo;
}

fn generateAndBindEBO(indices: []u16) c_uint {
    var ebo: c_uint = undefined;
    if (indices.len > 0) {
        gl.GenBuffers(1, @ptrCast(&ebo));
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(indices.len * @sizeOf(u32)), indices.ptr, gl.STATIC_DRAW);
    }

    return ebo;
}

fn createTexture(width: c_int, height: c_int, data: []const u8) c_uint {
    var texture: c_uint = undefined;
    gl.GenTextures(1, @ptrCast(&texture));
    gl.BindTexture(gl.TEXTURE_2D, texture);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_R, gl.REPEAT);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        width,
        height,
        0,
        gl.RGB,
        gl.UNSIGNED_BYTE,
        data.ptr,
    );

    gl.GenerateMipmap(gl.TEXTURE_2D);

    return texture;
}

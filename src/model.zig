const std = @import("std");
const zgltf = @import("zgltf");
const gl = @import("gl");
const zigimg = @import("zigimg");

const Mesh = struct {
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint = 0,
    n_vertices: c_int,
    n_indices: c_int = 0,
    texture: c_uint = 0,

    fn render(self: Mesh) void {
        if (self.texture > 0) {
            gl.BindTexture(gl.TEXTURE_2D, self.texture);
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
    meshes: std.ArrayList(Mesh),

    pub fn render(self: Model) void {
        for (self.meshes.items) |mesh| {
            mesh.render();
        }
    }

    pub fn deinit(self: *Model) void {
        var i: usize = 0;
        while (i < self.meshes.items.len) : (i += 1) {
            var mesh = &self.meshes.items[i];
            mesh.deinit();
        }
        self.meshes.deinit();
    }
};

pub fn cube(allocator: std.mem.Allocator) !Model {
    var vertices = [_]f32 {
//       POSITIONS          TEXTURE COORDS       NORMALS
//       FRONT
        -0.5,  0.5,  0.5,   0.0, 1.0,            0.0,  0.0,  1.0,
         0.5,  0.5,  0.5,   1.0, 1.0,            0.0,  0.0,  1.0,
         0.5, -0.5,  0.5,   1.0, 0.0,            0.0,  0.0,  1.0,
        -0.5, -0.5,  0.5,   0.0, 0.0,            0.0,  0.0,  1.0,
//       BACK
         0.5,  0.5, -0.5,   0.0, 1.0,            0.0,  0.0, -1.0,
        -0.5,  0.5, -0.5,   1.0, 1.0,            0.0,  0.0, -1.0,
        -0.5, -0.5, -0.5,   1.0, 0.0,            0.0,  0.0, -1.0,
         0.5, -0.5, -0.5,   0.0, 0.0,            0.0,  0.0, -1.0,
//       LEFT
        -0.5,  0.5, -0.5,   0.0, 1.0,           -1.0,  0.0,  0.0,
        -0.5,  0.5,  0.5,   1.0, 1.0,           -1.0,  0.0,  0.0,
        -0.5, -0.5,  0.5,   1.0, 0.0,           -1.0,  0.0,  0.0,
        -0.5, -0.5, -0.5,   0.0, 0.0,           -1.0,  0.0,  0.0,
//      RIGHT
         0.5,  0.5,  0.5,   0.0, 1.0,            1.0,  0.0,  0.0,
         0.5,  0.5, -0.5,   1.0, 1.0,            1.0,  0.0,  0.0,
         0.5, -0.5, -0.5,   1.0, 0.0,            1.0,  0.0,  0.0,
         0.5, -0.5,  0.5,   0.0, 0.0,            1.0,  0.0,  0.0,
//       TOP
        -0.5,  0.5, -0.5,   0.0, 1.0,            0.0,  1.0,  0.0,
         0.5,  0.5, -0.5,   1.0, 1.0,            0.0,  1.0,  0.0,
         0.5,  0.5,  0.5,   1.0, 0.0,            0.0,  1.0,  0.0,
        -0.5,  0.5,  0.5,   0.0, 0.0,            0.0,  1.0,  0.0,
//       BOTTOM
         0.5,  0.5, -0.5,   0.0, 1.0,            0.0, -1.0,  0.0,
        -0.5,  0.5,  0.5,   1.0, 1.0,            0.0, -1.0,  0.0,
        -0.5,  0.5,  0.5,   1.0, 0.0,            0.0, -1.0,  0.0,
         0.5,  0.5, -0.5,   0.0, 0.0,            0.0, -1.0,  0.0,
    };

    var indices = [_]u16 {
//      FRONT
        0, 1, 2,
        0, 2, 3,
//      BACK
        4, 5, 6,
        4, 6, 7,
//      LEFT
        8, 9, 10,
        8, 10, 11,
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
    try meshes.append(.{
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .n_vertices = vertices.len,
        .n_indices = indices.len,
    });

    return Model {
        .meshes = meshes,
    };
}

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

    try gltf.parse(buffer);

    var meshes = std.ArrayList(Mesh).init(allocator);

    // ===[ Gather Vertices ]===
    for (gltf.data.meshes.items) |mesh| {
        const dirPath = std.fs.path.dirname(gltfPath).?;
        const parsedMesh = try parseMesh(
            allocator,
            mesh,
            gltf,
            bin,
            dirPath,
        );
        try meshes.append(parsedMesh);
    }

    return Model {
        .meshes = meshes,
    };
}

fn parseMesh(allocator: std.mem.Allocator, mesh: zgltf.Mesh, gltf: zgltf, bin: [] const u8, meshPath: [] const u8) !Mesh {
    // ===[ Initialization ]===
    var vertexpositions: std.ArrayList(f32) = std.ArrayList(f32).init(allocator);
    defer vertexpositions.deinit();

    var texcoords: std.ArrayList(f32) = std.ArrayList(f32).init(allocator);
    defer texcoords.deinit();

    var normals: std.ArrayList(f32) = std.ArrayList(f32).init(allocator);

    var indices: std.ArrayList(u16) = std.ArrayList(u16).init(allocator);
    defer indices.deinit();

    var texture: c_uint = 0;

    // ===[ Parse all primitives ]===
    for (mesh.primitives.items) |primitive| {
        for (primitive.attributes.items) |attribute| {
            switch (attribute) {
                .position => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    gltf.getDataFromBufferView(f32, &vertexpositions, accessor, bin);
                },
                .texcoord => |accessor_index| {
                    const accessor = gltf.data.accessors.items[accessor_index];
                    gltf.getDataFromBufferView(f32, &texcoords, accessor, bin);
                },
                .normal => |normal_index| {
                    const accessor = gltf.data.accessors.items[normal_index];
                    gltf.getDataFromBufferView(f32, &normals, accessor, bin);
                },
                else => {}
            }
        }
        if (primitive.indices) |indices_index| {
            const accessor = gltf.data.accessors.items[indices_index];
            gltf.getDataFromBufferView(u16, &indices, accessor, bin);
        }
        if (primitive.material) |material_index| {
            const material = gltf.data.materials.items[material_index];
            const texture_index = material.metallic_roughness.base_color_texture.?.index;
            const source_index = gltf.data.textures.items[texture_index].source.?;
            const imageInfo = gltf.data.images.items[source_index];
            const uri = imageInfo.uri.?;
            const texturePath = try std.fs.path.join(allocator, &[_][]const u8 {meshPath, uri});
            var imageFile = try std.fs.cwd().openFile(texturePath, .{});
            var image = try zigimg.Image.fromFile(allocator, &imageFile);
            defer image.deinit();
            const width: c_int = @intCast(image.width);
            const height: c_int = @intCast(image.height);
            texture = createTexture(width, height, image.rawBytes());
        }
    }

    // ===[ Combine into final vertex array ]===
    var vertices = try std.ArrayList(f32).initCapacity(allocator, vertexpositions.items.len / 3);

    for (0..vertexpositions.items.len / 3, 0.., 0..) |vertexindex, texindex, normal_index| {
        try vertices.appendSlice(vertexpositions.items[3 * vertexindex..3 * vertexindex + 3]);
        try vertices.appendSlice(texcoords.items[2 * texindex..2 * texindex + 2]);
        try vertices.appendSlice(normals.items[3 * normal_index..3 * normal_index + 3]);
    }

    // ===[ Initialize OpenGL vars ]===
    const vao = generateAndBindVAO();
    const vbo = generateAndBindVBO(vertices.items);
    const ebo = generateAndBindEBO(indices.items);

    generateVertexAttribs();

    gl.BindVertexArray(0);

    return Mesh {
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .n_vertices = @intCast(vertexpositions.items.len / 3),
        .n_indices = @intCast(indices.items.len),
        .texture = texture,
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
    gl.BufferData(
        gl.ARRAY_BUFFER,
        @intCast(vertices.len * @sizeOf(f32)),
        vertices.ptr,
        gl.STATIC_DRAW
    );

    return vbo;
}

fn generateAndBindEBO(indices: []u16) c_uint {
    var ebo: c_uint = undefined;
    if (indices.len > 0) {
        gl.GenBuffers(1, @ptrCast(&ebo));
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
        gl.BufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @intCast(indices.len * @sizeOf(u32)),
            indices.ptr,
            gl.STATIC_DRAW
        );
    }

    return ebo;
}

fn createTexture(width: c_int, height: c_int, data: [] const u8) c_uint {
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

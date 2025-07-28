const std = @import("std");
const zgltf = @import("zgltf");
const gl = @import("gl");
const zigimg = @import("zigimg");

const Mesh = struct {
    vao: c_uint,
    n_vertices: c_int,
    n_indices: c_int,
    texture: c_uint,

    fn render(self: Mesh) void {
        gl.BindTexture(gl.TEXTURE_2D, self.texture);
        gl.BindVertexArray(self.vao);
        if (self.n_indices > 0) {
            gl.DrawElements(gl.TRIANGLES, self.n_indices, gl.UNSIGNED_SHORT, 0);
        } else {
            gl.DrawArrays(gl.TRIANGLES, 0, self.n_vertices);
        }
    }
};

pub const Model = struct {
    meshes: std.ArrayList(Mesh),

    pub fn render(self: Model) void {
        for (self.meshes.items) |mesh| {
            mesh.render();
        }
    }

    pub fn deinit(self: Model) void {
        self.meshes.deinit();
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
    var vertices = try std.ArrayList(f32).initCapacity(allocator, vertexpositions.items.len / 3);

    for (0..vertexpositions.items.len / 3, 0.., 0..) |vertexindex, texindex, normal_index| {
        try vertices.appendSlice(vertexpositions.items[3 * vertexindex..3 * vertexindex + 3]);
        try vertices.appendSlice(texcoords.items[2 * texindex..2 * texindex + 2]);
        try vertices.appendSlice(normals.items[3 * normal_index..3 * normal_index + 3]);
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

    if (indices.items.len > 0) {
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

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 5 * @sizeOf(f32));
    gl.EnableVertexAttribArray(2);

    gl.BindVertexArray(0);

    return Mesh {
        .vao = vao,
        .n_vertices = @intCast(vertexpositions.items.len / 3),
        .n_indices = @intCast(indices.items.len),
        .texture = texture,
    };
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

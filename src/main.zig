const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const c = @cImport(
    {
        @cInclude("SDL3/SDL.h");
        @cInclude("SDL3/SDL_main.h");
    }
);
const gl = @import("gl");
const zm = @import("zm");
const zigimg = @import("zigimg");
const Shader = @import("shader.zig");
const Camera = @import("camera.zig");
const Model = @import("model.zig");

var procs: gl.ProcTable = undefined;

const VERTICES = [_] f32 {
//  VERTEX COORDS       TEXTURE COORDS
    -0.5,   0.5, 0.0,   0.0, 1.0,
     0.5,   0.5, 0.0,   1.0, 1.0,
     0.5,  -0.5, 0.0,   1.0, 0.0,
    -0.5,  -0.5, 0.0,   0.0, 0.0,
};

const INDICES = [_] u32 {
    0, 1, 2,
    0, 2, 3,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    // ===[ SDL and Windowing ]===
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        return error.CouldNotInitSDL;
    }

    var aspectratio: f32 = 800.0 / 600.0;
    const window: *c.SDL_Window = c.SDL_CreateWindow("Videogame", 800, 600, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE).?;
    defer c.SDL_DestroyWindow(window);

    if (!c.SDL_SetWindowRelativeMouseMode(window, true)) {
        return error.CouldNotGrabMouse;
    }
    defer _ = c.SDL_SetWindowRelativeMouseMode(window, false);

    if (!c.SDL_SetWindowMouseGrab(window, true)) {
        return error.CouldNotGrabMouse;
    }
    defer _ = c.SDL_SetWindowMouseGrab(window, false);

    // ===[ OpenGL init ]===
    const glContext: c.SDL_GLContext = c.SDL_GL_CreateContext(window);
    defer _ = c.SDL_GL_DestroyContext(glContext);

    if (!procs.init(c.SDL_GL_GetProcAddress)) {
        return error.CouldNotInitGL;
    }

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    // ===[ OpenGL Settings ]===
    gl.Enable(gl.DEPTH_TEST);

    // ===[ Buffers ]===
    var vao: c_uint = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    gl.BindVertexArray(vao);

    var vbo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(VERTICES)), &VERTICES, gl.STATIC_DRAW);

    var ebo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&ebo));
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(INDICES)), &INDICES, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);

    // ===[ Textures ]===
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_R, gl.REPEAT);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    var texture: c_uint = undefined;
    gl.GenTextures(1, @ptrCast(&texture));
    gl.BindTexture(gl.TEXTURE_2D, texture);

    {
        const exePath = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exePath);
        const texturePath = try std.fs.path.join(allocator, &[_][]const u8{exePath, "/assets/textures/texture.png"});
        defer allocator.free(texturePath);
        var textureImage = try zigimg.Image.fromFilePath(allocator, texturePath);
        defer textureImage.deinit();
        try textureImage.flipVertically();
        gl.TexImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGBA,
            @intCast(textureImage.width),
            @intCast(textureImage.height),
            0,
            gl.RGB,
            gl.UNSIGNED_BYTE,
            textureImage.rawBytes().ptr
        );
        gl.GenerateMipmap(gl.TEXTURE_2D);
    }

    gl.BindVertexArray(0);

    // ===[ Shaders ]===
    const shader = try Shader.init(@embedFile("shaders/basic.vert"), @embedFile("shaders/basic.frag"));
    const texturedShader = try Shader.init(@embedFile("shaders/textured.vert"), @embedFile("shaders/textured.frag"));

    // ===[ Model ]===
    const suzanne = try Model.init(allocator, "assets/models/Suzanne.gltf", "assets/models/Suzanne.bin");
    defer suzanne.deinit();
    
    // ===[ Game Setup ]===
    var camera = Camera.init();
    var cameraDirection = zm.Vec3f { 0.0, 0.0, 0.0 };
    var done: bool = false;

    var lasttime = c.SDL_GetTicks();

    while (!done) {
        const curtime = c.SDL_GetTicks();
        var dt: f32 = @floatFromInt(curtime - lasttime);
        dt /= 1000.0;
        lasttime = curtime;

        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => done = true,
                c.SDL_EVENT_KEY_DOWN => switch (event.key.key) {
                    c.SDLK_Q => 
                        done = true,
                    c.SDLK_W => 
                        cameraDirection[2] =  1,
                    c.SDLK_A => 
                        cameraDirection[0] = -1,
                    c.SDLK_S => 
                        cameraDirection[2] = -1,
                    c.SDLK_D => 
                        cameraDirection[0] =  1,
                    c.SDLK_SPACE =>
                        cameraDirection[1] =  1,
                    c.SDLK_LSHIFT =>
                        cameraDirection[1] = -1,
                    else     => {},
                },
                c.SDL_EVENT_KEY_UP => switch(event.key.key) {
                    c.SDLK_W => if (cameraDirection[2] == 1) {
                        cameraDirection[2] = 0;
                    },
                    c.SDLK_A => if (cameraDirection[0] == -1) {
                        cameraDirection[0] = 0;
                    },
                    c.SDLK_S => if (cameraDirection[2] == -1) {
                        cameraDirection[2] = 0;
                    },
                    c.SDLK_D => if (cameraDirection[0] == 1) {
                        cameraDirection[0] = 0;
                    },
                    c.SDLK_SPACE => if (cameraDirection[1] == 1) {
                        cameraDirection[1] = 0;
                    },
                    c.SDLK_LSHIFT => if (cameraDirection[1] == -1) {
                        cameraDirection[1] = 0;
                    },
                    else     => {},
                },
                c.SDL_EVENT_MOUSE_MOTION => 
                    camera.applyMouseMovement(event.motion.xrel, event.motion.yrel),
                c.SDL_EVENT_WINDOW_RESIZED => {
                    const windowWidth: f32 = @floatFromInt(event.window.data1);
                    const windowHeight: f32 = @floatFromInt(event.window.data2);
                    aspectratio = windowWidth / windowHeight;
                    gl.Viewport(0, 0, event.window.data1, event.window.data2);
                },
                else => {}
            }
        }

        gl.ClearColor(0.5, 1.0, 0.5, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        camera.move(cameraDirection, dt);

        const model = zm.Mat4f.translation(2.0, 0.0, -3.0);
        const view = camera.getViewMatrix();
        const projection = zm.Mat4f.perspective(std.math.degreesToRadians(90.0), aspectratio, 0.1, 100.0);

        texturedShader.use();
        texturedShader.setMat4f("model", &model);
        texturedShader.setMat4f("view", &view);
        texturedShader.setMat4f("projection", &projection);

        gl.BindTexture(gl.TEXTURE_2D, texture);
        gl.BindVertexArray(vao);
        gl.DrawElements(gl.TRIANGLES, INDICES.len, gl.UNSIGNED_INT, 0);

        texturedShader.use();
        const suzannePos = zm.Mat4f.translation(-2.0, 0.0, -3.0);
        shader.setMat4f("model", &suzannePos);
        shader.setMat4f("view", &view);
        shader.setMat4f("projection", &projection);
        suzanne.render();

        _ = c.SDL_GL_SwapWindow(window);
    }
}

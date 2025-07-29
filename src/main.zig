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
//  VERTEX COORDS       TEXTURE COORDS  NORMALS
    -0.5,   0.5, 0.0,   0.0, 1.0,       0.0, 0.0, 1.0,
     0.5,   0.5, 0.0,   1.0, 1.0,       0.0, 0.0, 1.0,
     0.5,  -0.5, 0.0,   1.0, 0.0,       0.0, 0.0, 1.0,
    -0.5,  -0.5, 0.0,   0.0, 0.0,       0.0, 0.0, 1.0,
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

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 5 * @sizeOf(f32));
    gl.EnableVertexAttribArray(2);

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
    const lightShader    = try Shader.init(@embedFile("shaders/basic.vert"), @embedFile("shaders/basic.frag"));
    const texturedShader = try Shader.init(@embedFile("shaders/textured.vert"), @embedFile("shaders/textured.frag"));

    // ===[ Models ]===
    var suzanne = try Model.init(allocator, "assets/models/Suzanne.gltf", "assets/models/Suzanne.bin");
    defer suzanne.deinit();

    var cube = try Model.cube(allocator);
    defer cube.deinit();
    
    // ===[ Game Setup ]===
    var camera = Camera.init();
    var cameraDirection = zm.Vec3f { 0.0, 0.0, 0.0 };
    var done: bool = false;

    var lasttime = c.SDL_GetTicks();

    while (!done) {
        const curtime = c.SDL_GetTicks();
        const timeFloat: f32 = @floatFromInt(curtime);
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

        gl.ClearColor(0.02, 0.02, 0.02, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        camera.move(cameraDirection, dt);

        const model = zm.Mat4f.translation(2.0, 0.0, -3.0);
        const view = camera.getViewMatrix();
        const projection = zm.Mat4f.perspective(std.math.degreesToRadians(90.0), aspectratio, 0.1, 100.0);

        const lightColor = zm.Vec3f {1.0, 1.0, 1.0};
        const lightAngle = std.math.degreesToRadians(timeFloat / 28.0);
        const lightRadius = 5.0;
        const lightPosVec = zm.Vec3f {std.math.cos(lightAngle) * lightRadius, 3.0, std.math.sin(lightAngle) * lightRadius};
        const lightPos = zm.Mat4f.translationVec3(lightPosVec);
        const lightScale = zm.Mat4f.scalingVec3(.{0.2, 0.2, 0.2});

        const lightModel = lightPos.multiply(lightScale);

        lightShader.use();

        texturedShader.setMat4f("model", &lightModel);
        texturedShader.setMat4f("view", &view);
        texturedShader.setMat4f("projection", &projection);

        cube.render();

        texturedShader.use();

        texturedShader.setVec3f("lightColor", &lightColor);
        texturedShader.setVec3f("lightPos", &lightPosVec);
        texturedShader.setFloat("ambientStrength", 0.1);

        texturedShader.setMat4f("model", &model);
        texturedShader.setMat4f("view", &view);
        texturedShader.setMat4f("projection", &projection);

        gl.BindTexture(gl.TEXTURE_2D, texture);
        gl.BindVertexArray(vao);
        gl.DrawElements(gl.TRIANGLES, INDICES.len, gl.UNSIGNED_INT, 0);

        texturedShader.use();
        const suzannePos = zm.Mat4f.translation(-2.0, 0.0, -3.0);
        const suzanneAngle: f32 = std.math.degreesToRadians(timeFloat / 42.0);
        const suzanneRot = zm.Mat4f.rotation(zm.vec.up(f32), suzanneAngle);
        const suzanneModel = suzannePos.multiply(suzanneRot);
        texturedShader.setMat4f("model", &suzanneModel);
        texturedShader.setMat4f("view", &view);
        texturedShader.setMat4f("projection", &projection);
        suzanne.render();

        _ = c.SDL_GL_SwapWindow(window);
    }
}

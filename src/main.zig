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
const Shader = @import("shader.zig");

var procs: gl.ProcTable = undefined;

const VERTEX_SOURCE = @embedFile("shaders/vertex.glsl");
const FRAGMENT_SOURCE = @embedFile("shaders/fragment.glsl");

const VERTICES = [_] f32 {
    -0.5,   0.5, 0.0,
     0.5,   0.5, 0.0,
     0.5,  -0.5, 0.0,
    -0.5,  -0.5, 0.0,
};

const INDICES = [_] u32 {
    0, 1, 2,
    0, 2, 3,
};

pub fn main() !void {
    // ===[ SDL and Windowing ]===
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        return error.CouldNotInitSDL;
    }

    var aspectratio: f32 = 800.0 / 600.0;
    const window: *c.SDL_Window = c.SDL_CreateWindow("Videogame", 800, 600, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE).?;
    defer c.SDL_DestroyWindow(window);

    // ===[ OpenGL init ]===
    const glContext: c.SDL_GLContext = c.SDL_GL_CreateContext(window);
    defer _ = c.SDL_GL_DestroyContext(glContext);

    if (!procs.init(c.SDL_GL_GetProcAddress)) {
        return error.CouldNotInitGL;
    }

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

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

    gl.VertexAttribPointer(0, 3, gl.FLOAT, 0, 0, 0);
    gl.EnableVertexAttribArray(0);

    gl.BindVertexArray(0);

    // ===[ Shaders ]===
    const shader = try Shader.init(VERTEX_SOURCE, FRAGMENT_SOURCE);
    
    // ===[ Game Setup ]===
    var done: bool = false;

    while (!done) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            switch (event.type) {
                c.SDL_EVENT_QUIT => done = true,
                c.SDL_EVENT_KEY_DOWN => switch (event.key.key) {
                    c.SDLK_Q => done = true,
                    else     => {},
                },
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
        gl.Clear(gl.COLOR_BUFFER_BIT);

        const model = zm.Mat4f.translation(-2.0, 0.0, -1.0);
        const camPos = zm.Mat4f.translation(0.0, 0.0, 0.0);
        const camRot = zm.Mat4f.lookAt(.{0.0, 0.0, 0.0}, .{-2.0, 0.0, -10.0}, zm.vec.up(f32));
        const view = camPos.multiply(camRot);
        const projection = zm.Mat4f.perspective(std.math.degreesToRadians(90.0), aspectratio, 0.1, 100.0);

        shader.setMat4f("model", &model);
        shader.setMat4f("view", &view);
        shader.setMat4f("projection", &projection);

        shader.use();
        gl.BindVertexArray(vao);
        gl.DrawElements(gl.TRIANGLES, INDICES.len, gl.UNSIGNED_INT, 0);
        _ = c.SDL_GL_SwapWindow(window);
    }
}

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

    const shaderTuple = struct {
        shader: c_uint,
        type: c_uint,
        source: [*] const u8,
    };

    // ===[ Shaders ]===
    var shaderData  = [2] shaderTuple {
        .{.shader = undefined, .type = gl.VERTEX_SHADER, .source = VERTEX_SOURCE.ptr},
        .{.shader = undefined, .type = gl.FRAGMENT_SHADER, .source = FRAGMENT_SOURCE.ptr},
    };

    const shaderProgram = gl.CreateProgram();

    for (&shaderData) |*data| {
        data.shader = gl.CreateShader(data.type);
        gl.ShaderSource(data.shader, 1, @ptrCast(&data.source), null);
        gl.CompileShader(data.shader);

        var success: c_int = undefined;
        gl.GetShaderiv(data.shader, gl.COMPILE_STATUS, &success);

        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            gl.GetShaderInfoLog(data.shader, 512, null, &infoLog);
            try stderr.print("{s}\n", .{infoLog});
            return error.CouldNotCompileShader;
        }

        gl.AttachShader(shaderProgram, data.shader);
    }

    gl.LinkProgram(shaderProgram);

    var success: c_int = undefined;
    gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        var infoLog: [512]u8 = undefined;
        gl.GetProgramInfoLog(shaderProgram, 512, null, &infoLog);
        try stderr.print("{s}\n", .{infoLog});
        return error.CouldNotLinkShader;
    }

    for (&shaderData) |*data| {
        gl.DeleteShader(data.shader);
    }

    
    var done: bool = false;

    while (!done) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            if (event.type == c.SDL_EVENT_QUIT) {
                done = true;
            }
        }

        gl.ClearColor(0.5, 1.0, 0.5, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.UseProgram(shaderProgram);
        gl.BindVertexArray(vao);
        gl.DrawElements(gl.TRIANGLES, INDICES.len, gl.UNSIGNED_INT, 0);
        _ = c.SDL_GL_SwapWindow(window);
    }
}

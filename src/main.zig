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

const RENDERWIDTH = 512;
const RENDERHEIGHT = 480;
const RENDERASPECTRATIO = @as(f32, @floatFromInt(RENDERWIDTH)) / @as(f32, @floatFromInt(RENDERHEIGHT));

const Window = struct {
    sdlWindow: *c.SDL_Window,
    width: i32 = 0,
    height: i32 = 0,
    renderX0: i32 = 0,
    renderY0: i32 = 0,
    renderX1: i32 = 0,
    renderY1: i32 = 0,
    aspectRatio: f32 = 0.0,

    pub fn init(width: i32, height: i32) !Window {
        const sdlWindow: *c.SDL_Window = c.SDL_CreateWindow(
            "Videogame",
            width, 
            height, 
            c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE
        ).?;

        var window = Window {
            .sdlWindow = sdlWindow,
        };

        window.resize(width, height);
        return window;
    }

    pub fn deinit(self: Window) void {
        defer c.SDL_DestroyWindow(self.sdlWindow);
    }

    pub fn resize(self: *Window, newWidth: i32, newHeight: i32) void {
        self.width = newWidth;
        self.height = newHeight;
        self.aspectRatio = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
        self.calculateRenderBounds();
    }

    fn calculateRenderBounds(self: *Window) void {
        if (self.aspectRatio > RENDERASPECTRATIO) {
            const theoreticalWidth: i32 = @intFromFloat(@as(f32, @floatFromInt(self.height)) * RENDERASPECTRATIO);
            const diff = self.width - theoreticalWidth;
            const offset = @divFloor(diff, 2);
            self.renderX0 = offset;
            self.renderX1 = self.width - offset;
            self.renderY0 = 0;
            self.renderY1 = self.height;
        } else {
            const theoreticalHeight: i32 = @intFromFloat(@as(f32, @floatFromInt(self.width)) / RENDERASPECTRATIO);
            const diff = self.height - theoreticalHeight;
            const offset = @divFloor(diff, 2);
            self.renderX0 = 0;
            self.renderX1 = self.width;
            self.renderY0 = offset;
            self.renderY1 = self.height - offset;
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();

    // ===[ SDL and Windowing ]===
    if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
        return error.CouldNotInitSDL;
    }

    var window = try Window.init(800, 600);
    defer window.deinit();

    // Could be moved to window struct
    if (!c.SDL_SetWindowRelativeMouseMode(window.sdlWindow, true)) {
        return error.CouldNotGrabMouse;
    }
    defer _ = c.SDL_SetWindowRelativeMouseMode(window.sdlWindow, false);

    if (!c.SDL_SetWindowMouseGrab(window.sdlWindow, true)) {
        return error.CouldNotGrabMouse;
    }
    defer _ = c.SDL_SetWindowMouseGrab(window.sdlWindow, false);

    // ===[ OpenGL init ]===
    const glContext: c.SDL_GLContext = c.SDL_GL_CreateContext(window.sdlWindow);
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
    defer gl.DeleteVertexArrays(1, @ptrCast(&vao));

    var vbo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&vbo));
    defer gl.DeleteBuffers(1, @ptrCast(&vbo));
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(VERTICES)), &VERTICES, gl.STATIC_DRAW);

    var ebo: c_uint = undefined;
    gl.GenBuffers(1, @ptrCast(&ebo));
    defer gl.DeleteBuffers(1, @ptrCast(&ebo));
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(INDICES)), &INDICES, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(2, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 5 * @sizeOf(f32));
    gl.EnableVertexAttribArray(2);

    var fbo: c_uint = undefined;
    gl.GenFramebuffers(1, @ptrCast(&fbo));
    defer gl.DeleteFramebuffers(1, @ptrCast(&fbo));
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);

    var fbtexture: c_uint = undefined;
    gl.GenTextures(1, @ptrCast(&fbtexture));
    defer gl.DeleteTextures(1, @ptrCast(&fbtexture));
    gl.BindTexture(gl.TEXTURE_2D, fbtexture);
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, RENDERWIDTH, RENDERHEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, null);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.BindTexture(gl.TEXTURE_2D, 0);

    gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fbtexture, 0);
    const e = gl.GetError();
    if (e != gl.NO_ERROR) {
        try stdout.print("{d}\n", .{e});
    }

    var rbo: c_uint = undefined;
    gl.GenRenderbuffers(1, @ptrCast(&rbo));
    gl.BindRenderbuffer(gl.RENDERBUFFER, rbo);
    gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, RENDERWIDTH, RENDERHEIGHT);
    gl.BindRenderbuffer(gl.RENDERBUFFER, 0);

    gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo);

    if (gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
        return error.FrameBufferNotComplete;
    }
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0);

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
                    window.resize(event.window.data1, event.window.data2);
                },
                else => {}
            }
        }

        gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);
        gl.Viewport(0, 0, RENDERWIDTH, RENDERHEIGHT);
        gl.ClearColor(0.02, 0.02, 0.2, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        camera.move(cameraDirection, dt);

        const model = zm.Mat4f.translation(2.0, 0.0, -3.0);
        const view = camera.getViewMatrix();
        const projection = zm.Mat4f.perspective(std.math.degreesToRadians(90.0), RENDERASPECTRATIO, 0.1, 100.0);

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

        gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.BindFramebuffer(gl.READ_FRAMEBUFFER, fbo);
        gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);
        gl.Viewport(0, 0, window.width, window.height);
        
        // Could be replaced with rendering to a big triangle/quad
        gl.BlitFramebuffer(0, 0, RENDERWIDTH, RENDERHEIGHT, window.renderX0, window.renderY0, window.renderX1, window.renderY1, gl.COLOR_BUFFER_BIT, gl.NEAREST);

        _ = c.SDL_GL_SwapWindow(window.sdlWindow);
    }
}

const std = @import("std");
const gl = @import("gl");
const zm = @import("zm");
const Shader = @import("shader.zig");
const Camera = @import("camera.zig");
const Model = @import("model.zig");
const Window = @import("window.zig");
const Object = @import("object.zig");
const physics = @import("physics.zig");
const sdl = @import("sdl3");
const c = @import("c.zig").imports;

const VERTICES = [_]f32{
    //  VERTEX COORDS       TEXTURE COORDS  NORMALS
    -0.5, 0.5,  0.0, 0.0, 1.0, 0.0, 0.0, 1.0,
    0.5,  0.5,  0.0, 1.0, 1.0, 0.0, 0.0, 1.0,
    0.5,  -0.5, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0,
    -0.5, -0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0,
};

const INDICES = [_]u32{
    0, 1, 2,
    0, 2, 3,
};

pub fn main() !void {
    defer sdl.shutdown();

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // ===[ SDL and Windowing ]===
    try sdl.init(.{ .video = true });

    var window = try Window.init(800, 600);
    defer window.deinit();
    // No idea why this needs to happen here as I also call this in the window init
    gl.makeProcTableCurrent(&window.proctable);
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
        const texturePath = try std.fs.path.join(allocator, &[_][]const u8{ exePath, "/assets/textures/texture.png" });
        defer allocator.free(texturePath);
        // var textureImage = try zigimg.Image.fromFilePath(allocator, texturePath);
        // defer textureImage.deinit();
        // try textureImage.flipVertically();
        // gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, @intCast(textureImage.width), @intCast(textureImage.height), 0, gl.RGB, gl.UNSIGNED_BYTE, textureImage.rawBytes().ptr);
        // gl.GenerateMipmap(gl.TEXTURE_2D);
    }

    gl.BindVertexArray(0);

    // ===[ Shaders ]===
    const lightShader = try Shader.init(@embedFile("shaders/basic.vert"), @embedFile("shaders/basic.frag"));
    const texturedShader = try Shader.init(@embedFile("shaders/textured.vert"), @embedFile("shaders/textured.frag"));

    // ===[ Objects ]===
    var om = Object.ObjectManager.init(allocator);
    defer om.deinit();
    var suzanneModel = try Model.init(allocator, "assets/models/Suzanne.gltf", "assets/models/Suzanne.bin", &texturedShader);
    defer suzanneModel.deinit();
    const s1 = try om.create(&suzanneModel);

    var s1physics: physics.PhysicsBody  = .{};

    om.get(s1).?.transform.position[1] = 4.0;
    _ = try om.create(&suzanneModel);
    _ = try om.create(&suzanneModel);

    var cubeModel = try Model.cube(allocator, &lightShader);
    defer cubeModel.deinit();

    // ===[ imgui setup ]===
    _ = c.CIMGUI_CHECKVERSION();
    _ = c.ImGui_CreateContext(null);
    defer c.ImGui_DestroyContext(null);

    const imio = c.ImGui_GetIO();
    imio.*.ConfigFlags = c.ImGuiConfigFlags_NavEnableKeyboard;

    c.ImGui_StyleColorsDark(null);

    _ = c.cImGui_ImplSDL3_InitForOpenGL(@ptrCast(window.sdlWindow.value), @ptrCast(window.glContext.value));
    defer c.cImGui_ImplSDL3_Shutdown();
    _ = c.cImGui_ImplOpenGL3_Init();
    defer c.cImGui_ImplOpenGL3_Shutdown();

    // ===[ Game Setup ]===
    var camera = Camera.init();
    var cameraDirection = zm.Vec3f{ 0.0, 0.0, 0.0 };
    var done: bool = false;

    var lasttime = sdl.timer.getMillisecondsSinceInit();

    var clearColor = [_]f32{ 0.02, 0.02, 0.2 };
    var snapVertices = true;

    while (!done) {
        const curtime = sdl.timer.getMillisecondsSinceInit();
        const timeFloat: f32 = @floatFromInt(curtime);
        var dt: f32 = @floatFromInt(curtime - lasttime);
        dt /= 1000.0;
        lasttime = curtime;

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();

        while (sdl.events.poll()) |event| {
            _ = c.cImGui_ImplSDL3_ProcessEvent(@ptrCast(&event.toSdl()));
            switch (event) {
                .quit => done = true,
                .key_down => |key_event| switch (key_event.key.?) {
                    .q => done = true,
                    .w => cameraDirection[2] = 1,
                    .a => cameraDirection[0] = -1,
                    .s => cameraDirection[2] = -1,
                    .d => cameraDirection[0] = 1,
                    .space => cameraDirection[1] = 1,
                    .left_shift => cameraDirection[1] = -1,
                    .escape => window.toggleMouseLocked() catch {},
                    else => {},
                },
                .key_up => |key_event| switch (key_event.key.?) {
                    .w => if (cameraDirection[2] == 1) {
                        cameraDirection[2] = 0;
                    },
                    .a => if (cameraDirection[0] == -1) {
                        cameraDirection[0] = 0;
                    },
                    .s => if (cameraDirection[2] == -1) {
                        cameraDirection[2] = 0;
                    },
                    .d => if (cameraDirection[0] == 1) {
                        cameraDirection[0] = 0;
                    },
                    .space => if (cameraDirection[1] == 1) {
                        cameraDirection[1] = 0;
                    },
                    .left_shift => if (cameraDirection[1] == -1) {
                        cameraDirection[1] = 0;
                    },
                    else => {},
                },
                .mouse_motion => |motion| if (window.mouse_locked) {
                    camera.applyMouseMovement(motion.x_rel, motion.y_rel);
                },
                .window_resized => |resize| {
                    try window.resize(resize.width, resize.height);
                },
                else => {},
            }
        }

        s1physics.applyGravity(dt);
        s1physics.applyVelocity(om.get(s1).?);

        window.framebuffer.bind();
        gl.Viewport(0, 0, @intCast(window.framebuffer.size.width), @intCast(window.framebuffer.size.height));
        gl.ClearColor(clearColor[0], clearColor[1], clearColor[2], 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        camera.move(cameraDirection, dt);

        const model = zm.Mat4f.translation(2.0, 0.0, -3.0);
        const view = camera.getViewMatrix();
        const projection = zm.Mat4f.perspective(std.math.degreesToRadians(90.0), window.size.aspectRatio, 0.1, 100.0);

        const lightColor = zm.Vec3f{ 1.0, 1.0, 1.0 };
        const lightAngle = std.math.degreesToRadians(timeFloat / 28.0);
        const lightRadius = 5.0;
        const lightPosVec = zm.Vec3f{ std.math.cos(lightAngle) * lightRadius, 3.0, std.math.sin(lightAngle) * lightRadius };
        const lightPos = zm.Mat4f.translationVec3(lightPosVec);
        const lightScale = zm.Mat4f.scalingVec3(.{ 0.2, 0.2, 0.2 });

        const lightModel = lightPos.multiply(lightScale);

        lightShader.use();

        lightShader.setMat4f("model", &lightModel);
        lightShader.setMat4f("view", &view);
        lightShader.setMat4f("projection", &projection);

        cubeModel.render();

        texturedShader.use();

        texturedShader.setVec3f("lightColor", &lightColor);
        texturedShader.setVec3f("lightPos", &lightPosVec);
        texturedShader.setFloat("ambientStrength", 0.1);

        texturedShader.setMat4f("model", &model);
        texturedShader.setMat4f("view", &view);
        texturedShader.setMat4f("projection", &projection);

        const resolutionVector = zm.Vec2f{ @as(f32, @floatFromInt(window.framebuffer.size.width)), @as(f32, @floatFromInt(window.framebuffer.size.height)) };
        texturedShader.setVec2f("targetResolution", &resolutionVector);

        texturedShader.setBool("snapVertices", snapVertices);

        gl.BindTexture(gl.TEXTURE_2D, texture);
        gl.BindVertexArray(vao);
        gl.DrawElements(gl.TRIANGLES, INDICES.len, gl.UNSIGNED_INT, 0);

        texturedShader.use();
        texturedShader.setMat4f("view", &view);
        texturedShader.setMat4f("projection", &projection);
        om.renderAll();

        gl.BindFramebuffer(gl.FRAMEBUFFER, 0);

        _ = c.ImGui_Begin("Game stuff", null, c.ImGuiWindowFlags_None);

        c.ImGui_Text("Framerate: %f", imio.*.Framerate);
        c.ImGui_Text("Frametime: %f", dt);
        _ = c.ImGui_ColorPicker3("Background color", @ptrCast(&clearColor), c.ImGuiColorEditFlags_None);
        _ = c.ImGui_Checkbox("Snap vertices", &snapVertices);

        c.ImGui_End();
        c.ImGui_Render();

        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        window.framebuffer.readBind();
        gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);
        gl.Viewport(0, 0, @intCast(window.size.width), @intCast(window.size.height));

        // Could be replaced with rendering to a big triangle/quad
        gl.BlitFramebuffer(0, 0, @intCast(window.framebuffer.size.width), @intCast(window.framebuffer.size.height), 0, 0, @intCast(window.size.width), @intCast(window.size.height), gl.COLOR_BUFFER_BIT, gl.NEAREST);

        c.cImGui_ImplOpenGL3_RenderDrawData(c.ImGui_GetDrawData());

        try sdl.video.gl.swapWindow(window.sdlWindow);
    }
}

const std = @import("std");
const gl = @import("gl");
const zm = @import("zm");
const Shader = @import("shader.zig");
const Camera = @import("camera.zig");
const Model = @import("model.zig");
const Window = @import("window.zig");
const Object = @import("Object.zig");
const physics = @import("physics.zig");
const sdl = @import("sdl3");
const c = @import("c.zig").imports;
const Transform = @import("components/Transform.zig");

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

    // ===[ Shaders ]===
    const lightShader = try Shader.init(@embedFile("shaders/basic.vert"), @embedFile("shaders/basic.frag"));
    const texturedShader = try Shader.init(@embedFile("shaders/textured.vert"), @embedFile("shaders/textured.frag"));

    var suzanneModel = try Model.init(allocator, "assets/models/Suzanne.gltf", "assets/models/Suzanne.bin", &texturedShader);
    defer suzanneModel.deinit();

    var objects = [_]Object{
        try Object.init(allocator, &suzanneModel, "Suzanne 1"),
        try Object.init(allocator, &suzanneModel, "Suzanne 2"),
        try Object.init(allocator, &suzanneModel, "Suzanne 3"),
    };

    var world = physics.World.init(allocator);
    defer world.deinit();

    for (&objects) |*o| {
        var pb = try world.createBody(&o.transform);
        pb.elasticity = 0.5;
    }

    // Ground
    var groundTransform: Transform = .{
        .position = .{ 0.0, -1000.0, 0.0 },
    };
    var groundBody = try world.createBody(&groundTransform);
    groundBody.shape.shapeType.sphere.radius = 1000.0;
    groundBody.inverseMass = 0.0;

    objects[0].transform.position = .{ 0.0, 10.0, 0.0 };

    objects[1].transform.position = .{ -5.0, 15.0, -4.0 };

    objects[2].transform.position = .{ 5.0, 10.0, -8.0 };

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
        const dt: f32 = @as(f32, @floatFromInt(curtime - lasttime)) / 1000.0;
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

        world.update(dt);

        window.framebuffer.bind();
        gl.Viewport(0, 0, @intCast(window.framebuffer.size.width), @intCast(window.framebuffer.size.height));
        gl.ClearColor(clearColor[0], clearColor[1], clearColor[2], 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        camera.move(cameraDirection, dt);

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

        const resolutionVector = zm.Vec2f{ @as(f32, @floatFromInt(window.framebuffer.size.width)), @as(f32, @floatFromInt(window.framebuffer.size.height)) };
        texturedShader.setVec2f("targetResolution", &resolutionVector);

        texturedShader.setBool("snapVertices", snapVertices);

        texturedShader.setMat4f("view", &view);
        texturedShader.setMat4f("projection", &projection);

        for (&objects) |*o| {
            o.render();
        }

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

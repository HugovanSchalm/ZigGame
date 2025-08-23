const c = @cImport(
    {
        @cInclude("SDL3/SDL.h");
        @cInclude("SDL3/SDL_main.h");
    }
);

pub const RENDERWIDTH = 512;
pub const RENDERHEIGHT = 480;
pub const RENDERASPECTRATIO = @as(f32, @floatFromInt(RENDERWIDTH)) / @as(f32, @floatFromInt(RENDERHEIGHT));

const Window = struct {
    sdlWindow: *c.SDL_Window,
    width: i32 = 0,
    height: i32 = 0,
    renderX0: i32 = 0,
    renderY0: i32 = 0,
    renderX1: i32 = 0,
    renderY1: i32 = 0,
    aspectRatio: f32 = 0.0,

    mouse_locked: bool = false,

    pub fn deinit(self: *Window) void {
        self.setMouseLocked(false) catch {};
        c.SDL_DestroyWindow(self.sdlWindow);
    }

    pub fn resize(self: *Window, newWidth: i32, newHeight: i32) void {
        self.width = newWidth;
        self.height = newHeight;
        self.aspectRatio = @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.height));
        self.calculateRenderBounds();
    }

    fn setMouseLocked(self: *Window, value: bool) !void {
        if (!c.SDL_SetWindowRelativeMouseMode(self.sdlWindow, value)) {
            return error.CouldNotSetMouseMode;
        }

        if (!c.SDL_SetWindowMouseGrab(self.sdlWindow, value)) {
            return error.CouldNotSetMouseGrab;
        }

        self.mouse_locked = value;
    }

    pub fn toggleMouseLocked(self: *Window) !void {
        try self.setMouseLocked(!self.mouse_locked);
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
    try window.setMouseLocked(true);
    return window;
}


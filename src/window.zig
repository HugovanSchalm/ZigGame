const sdl = @import("sdl3");
const gl = @import("gl");

const MINRENDERSIDESIZE = 240;

const SurfaceSize = struct {
    width: usize,
    height: usize,
    aspectRatio: f32,
};


const FrameBuffer = struct {
    fbo: c_uint = undefined,
    fbtexture: c_uint = undefined,
    depthstencilrbo: c_uint = undefined,
    size: SurfaceSize,

    fn init(size: SurfaceSize) !FrameBuffer {
        var fbo: c_uint = undefined;
        gl.GenFramebuffers(1, @ptrCast(&fbo));
        gl.BindFramebuffer(gl.FRAMEBUFFER, fbo);

        var fbtexture: c_uint = undefined;
        gl.GenTextures(1, @ptrCast(&fbtexture));
        gl.BindTexture(gl.TEXTURE_2D, fbtexture);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, @intCast(size.width), @intCast(size.height), 0, gl.RGB, gl.UNSIGNED_BYTE, null);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        gl.BindTexture(gl.TEXTURE_2D, 0);

        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fbtexture, 0);

        var rbo: c_uint = undefined;
        gl.GenRenderbuffers(1, @ptrCast(&rbo));
        gl.BindRenderbuffer(gl.RENDERBUFFER, rbo);
        gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, @intCast(size.width), @intCast(size.height));
        gl.BindRenderbuffer(gl.RENDERBUFFER, 0);

        gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo);

        if (gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            return error.FrameBufferNotComplete;
        }

        FrameBuffer.unbind();

        return FrameBuffer {
            .fbo = fbo,
            .fbtexture = fbtexture,
            .depthstencilrbo = rbo,
            .size = size,
        };
    }

    fn deinit(self: *FrameBuffer) void {
        gl.DeleteFramebuffers(1, @ptrCast(&self.fbo));
        gl.DeleteTextures(1, @ptrCast(&self.fbtexture));
        gl.DeleteRenderbuffers(1, @ptrCast(&self.depthstencilrbo));
        FrameBuffer.unbind();
    }

    pub fn bind(self: FrameBuffer) void {
        gl.BindFramebuffer(gl.FRAMEBUFFER, self.fbo);
    }

    pub fn readBind(self: FrameBuffer) void {
        gl.BindFramebuffer(gl.READ_FRAMEBUFFER, self.fbo);
    }

    pub fn unbind() void {
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0);
    }
};

const Window = struct {
    sdlWindow: sdl.video.Window,
    glContext: sdl.video.gl.Context,
    proctable: gl.ProcTable = undefined,
    size: SurfaceSize,
    framebuffer: FrameBuffer,
    minRenderSideSize: i32 = 240,

    mouse_locked: bool = false,

    pub fn deinit(self: *Window) void {
        self.setMouseLocked(false) catch {};
        self.sdlWindow.deinit();
        self.glContext.deinit() catch {};
        gl.makeProcTableCurrent(null);
    }

    pub fn resize(self: *Window, newWidth: i32, newHeight: i32) !void {
        const width: usize = @intCast(newWidth);
        const height: usize = @intCast(newHeight);
        self.size.width = @intCast(width);
        self.size.height = @intCast(height);
        self.size.aspectRatio = calcAspectRatio(width, height);
        self.framebuffer.deinit();
        self.framebuffer = try FrameBuffer.init(calcFrameBufferSize(self.size));
    }

    fn setMouseLocked(self: *Window, value: bool) !void {
        try sdl.mouse.setWindowGrab(self.sdlWindow, value);
        try sdl.mouse.setWindowRelativeMode(self.sdlWindow, value);
        self.mouse_locked = value;
    }

    pub fn toggleMouseLocked(self: *Window) !void {
        try self.setMouseLocked(!self.mouse_locked);
    }
};

fn calcAspectRatio(width: usize, height: usize) f32 {
    return @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height));
}

fn calcFrameBufferSize(windowSize: SurfaceSize) SurfaceSize {
    const width: usize = 
        if (windowSize.width <= windowSize.height)
            MINRENDERSIDESIZE
        else
            @intFromFloat(@as(f32, @floatFromInt(MINRENDERSIDESIZE)) * windowSize.aspectRatio);
    const height: usize = 
        if (windowSize.width > windowSize.height)
            MINRENDERSIDESIZE
        else
            @intFromFloat(@as(f32, @floatFromInt(MINRENDERSIDESIZE)) / windowSize.aspectRatio);

    return .{
        .width = width,
        .height = height,
        .aspectRatio = windowSize.aspectRatio,
    };
}

pub fn init(width: usize, height: usize) !Window {
    const sdlWindow = try sdl.video.Window.init(
        "Videogame",
        width,
        height,
        .{
            .open_gl = true,
            .resizable = true,
            .fullscreen = true,
        }
    );

    const glContext = try sdl.video.gl.Context.init(sdlWindow);
    try glContext.makeCurrent(sdlWindow);
    try sdl.video.gl.setSwapInterval(.vsync);


    var procs: gl.ProcTable = undefined;
    if (!procs.init(sdl.c.SDL_GL_GetProcAddress)) {
        return error.CouldNotInitGL;
    }

    gl.makeProcTableCurrent(&procs);

    const windowSize = SurfaceSize {
        .width = width,
        .height = height,
        .aspectRatio = calcAspectRatio(width, height),
    };

    const fbsize = calcFrameBufferSize(windowSize);
    const framebuffer = try FrameBuffer.init(fbsize);

    var window = Window{
        .sdlWindow = sdlWindow,
        .glContext = glContext,
        .size = windowSize,
        .framebuffer = framebuffer,
        .proctable = procs
    };

    try window.setMouseLocked(true);
    return window;
}

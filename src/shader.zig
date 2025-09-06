const std = @import("std");
const gl = @import("gl");
const zm = @import("zm");

pub const Shader = struct {
    id: u32,

    pub fn use(self: Shader) void {
        gl.UseProgram(self.id);
    }

    pub fn setBool(self: Shader, name: [*:0]const u8, value: bool) void {
        const uniformLocation = gl.GetUniformLocation(self.id, name);
        gl.Uniform1i(uniformLocation, if (value) 1 else 0);
    }

    pub fn setFloat(self: Shader, name: [*:0]const u8, value: f32) void {
        const uniformLocation = gl.GetUniformLocation(self.id, name);
        gl.Uniform1f(uniformLocation, value);
    }

    pub fn setVec2f(self: Shader, name: [*:0]const u8, value: *const zm.Vec2f) void {
        const uniformLocation = gl.GetUniformLocation(self.id, name);
        gl.Uniform2fv(uniformLocation, 1, @ptrCast(value));
    }

    pub fn setVec3f(self: Shader, name: [*:0]const u8, value: *const zm.Vec3f) void {
        const uniformLocation = gl.GetUniformLocation(self.id, name);
        gl.Uniform3fv(uniformLocation, 1, @ptrCast(value));
    }

    pub fn setVec4f(self: Shader, name: [*:0]const u8, value: *const zm.Vec4f) void {
        const uniformLocation = gl.GetUniformLocation(self.id, name);
        gl.Uniform4fv(uniformLocation, 1, @ptrCast(value));
    }

    pub fn setMat4f(self: Shader, name: [*:0]const u8, value: *const zm.Mat4f) void {
        const uniformLocation = gl.GetUniformLocation(self.id, name);
        gl.UniformMatrix4fv(uniformLocation, 1, gl.TRUE, @ptrCast(value));
    }
};

pub fn init(vertexSource: []const u8, fragmentSource: []const u8) !Shader {
    const programId = gl.CreateProgram();

    var shaders = [_]c_uint{ undefined, undefined };
    const types = [_]c_uint{ gl.VERTEX_SHADER, gl.FRAGMENT_SHADER };
    const sources = [_][*]const u8{ vertexSource.ptr, fragmentSource.ptr };

    for (&shaders, types, sources) |*shader, shaderType, source| {
        shader.* = gl.CreateShader(shaderType);
        gl.ShaderSource(shader.*, 1, @ptrCast(&source), null);
        gl.CompileShader(shader.*);

        var success: c_int = undefined;
        gl.GetShaderiv(shader.*, gl.COMPILE_STATUS, @ptrCast(&success));

        if (success == 0) {
            var infoLog: [512]u8 = undefined;
            gl.GetShaderInfoLog(shader.*, 512, null, &infoLog);
            // try stderr.print("{s}\n", .{infoLog});
            return error.CouldNotCompileShader;
        }

        gl.AttachShader(programId, shader.*);
    }

    gl.LinkProgram(programId);

    for (shaders) |shader| {
        gl.DeleteShader(shader);
    }

    var success: c_int = undefined;
    gl.GetProgramiv(programId, gl.LINK_STATUS, @ptrCast(&success));
    if (success == 0) {
        var infoLog: [512]u8 = undefined;
        gl.GetProgramInfoLog(programId, 512, null, &infoLog);
        // try stderr.print("{s}\n", .{infoLog});
        return error.CouldNotLinkShader;
    }

    return .{ .id = programId };
}

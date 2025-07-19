const std = @import("std");
const zm = @import("zm");

pub const Camera = struct {
    worldup: zm.Vec3f,

    position: zm.Vec3f,
    right: zm.Vec3f,
    front: zm.Vec3f,
    up: zm.Vec3f,

    pitch: f32,
    roll: f32,
    yaw: f32,

    movespeed: f32,
    sensitivity: f32,

    pub fn move(self: *Camera, direction: zm.Vec3f, dt: f32) void {
        var movedir = zm.Vec3f { 0.0, 0.0, 0.0 };
        const camfront  = zm.vec.normalize(zm.Vec3f { self.front[0], 0.0, self.front[2] });
        movedir += zm.vec.scale(camfront, direction[2]);
        const camright  = zm.vec.normalize(zm.Vec3f { self.right[0], 0.0, self.right[2] });
        movedir += zm.vec.scale(camright, direction[0]);
        if (zm.vec.len(movedir) > 0) {
            movedir = zm.vec.normalize(movedir);
        }
        self.position += zm.vec.scale(movedir, dt * self.movespeed);
        self.position[1] += direction[1] * dt * self.movespeed;
    }

    pub fn getViewMatrix(self: Camera) zm.Mat4f {
        return zm.Mat4f.lookAt(self.position, self.position + self.front, self.up);
    }

    pub fn applyMouseMovement(self: *Camera, dx: f32, dy: f32) void {
        self.pitch -= self.sensitivity * dy;
        self.pitch = std.math.clamp(self.pitch, -89.0, 89.0);
        self.yaw += self.sensitivity * dx;
        self.updateVectors();
    }
    
    fn updateVectors(self: *Camera) void {
        self.front[0] = 
            std.math.cos(std.math.degreesToRadians(self.yaw)) * 
            std.math.cos(std.math.degreesToRadians(self.pitch));
        self.front[1] = std.math.sin(std.math.degreesToRadians(self.pitch));
        self.front[2] =
            std.math.sin(std.math.degreesToRadians(self.yaw)) *
            std.math.cos(std.math.degreesToRadians(self.pitch));

        self.front  = zm.vec.normalize(self.front);
        self.right  = zm.vec.normalize(zm.vec.cross(self.front, self.worldup));
        self.up     = zm.vec.normalize(zm.vec.cross(self.right, self.front));
    }
};

pub fn init() Camera {
    return .{
        .worldup = zm.vec.up(f32),
        .position = zm.Vec3f {0.0, 0.0, 2.0},
        .front = -zm.vec.forward(f32),
        .right = zm.vec.right(f32),
        .up = zm.vec.up(f32),
        .pitch = 0.0,
        .roll = 0.0,
        .yaw = -90.0,
        .movespeed = 2.5,
        .sensitivity = 0.1,
    };
}

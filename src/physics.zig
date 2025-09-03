const std = @import("std");
const zm = @import("zm");
const Object = @import("object.zig").Object;

const GRAVITY = 9.8;
const MAX_FALL_VELOCITY = 100.0;

const Velocity = zm.Vec3f;

pub const PhysicsBody = struct {
    velocity: Velocity = zm.vec.zero(3, f32),

    pub fn applyGravity(self: *PhysicsBody, dt: f32) void {
        self.velocity[1] -= dt * GRAVITY;
        self.velocity[1] = std.math.clamp(self.velocity[1], -MAX_FALL_VELOCITY, MAX_FALL_VELOCITY);
    }

    pub fn apply(self: *PhysicsBody, to: *Object, dt: f32) void {
        to.transform.position += zm.vec.scale(self.velocity, dt);
        if (to.transform.position[1] <= 0.0) {
            to.transform.position[1] = 0.0;
            self.velocity[1] = 0.0;
        }
    }
};

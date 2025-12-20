const std = @import("std");
const zm = @import("zm");
const Object = @import("object.zig").Object;

const GRAVITY = 9.8;
const MAX_FALL_VELOCITY = 100.0;

const Velocity = zm.Vec3f;

pub const Sphere = struct {
    radius: f32,
};

pub const Shape = union(enum) {
    sphere: Sphere,

    pub fn getCenterOfMass(self: Shape) zm.Vec3f {
        // TODO: enable changing of com
        _ = self;
        return zm.vec.zero(3, f32);
    }
};

pub const Body = struct {
    position: zm.Vec3f,
    rotation: zm.Quaternionf,
    shape: Shape,
};

pub const Scene = struct {
    bodies: std.ArrayList(Body),

    pub fn init() void {
        return;
    }

    pub fn update(dt: f32) void {
        _ = dt;
    }

    pub fn getCenterOfMassWorldSpace(self: Body) zm.Vec3f {
        const com = self.shape.getCenterOfMass();
    }
};

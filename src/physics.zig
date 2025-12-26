const std = @import("std");
const zm = @import("zm");
const Transform = @import("components/Transform.zig");

const Velocity = zm.Vec3f;

const GRAVITY = -9.8;

pub const Sphere = struct {
    radius: f32 = 1.0,
};

pub const ShapeType = union(enum) {
    sphere: Sphere,
};

pub const Shape = struct {
    shapeType: ShapeType = .{ .sphere = .{} },
    com: zm.Vec3f = zm.vec.zero(3, f32),
};

pub const PhysicsBody = struct {
    transform: *Transform,
    linearVelocity: zm.Vec3f = zm.vec.zero(3, f32),
    shape: Shape = .{},

    pub fn centerOfMassWorldSpace(self: *const PhysicsBody) zm.Vec3f {
        const com = self.shape.com;
        const pos = self.position;
        return com + pos;
    }

    pub fn centerOfMassBodySpace(self: *const PhysicsBody) zm.Vec3f {
        return self.shape.com;
    }

    pub fn worldToBodySpace(self: *const PhysicsBody, point: zm.Vec3f) zm.Vec3f {
        const tmp = point - self.centerOfMassWorldSpace();
        const inverseOrient = self.rotation.inverse();

        const quaternionVector = zm.Quaternionf.fromVec3(0.0, tmp);
        const rotated = inverseOrient.multiply(quaternionVector).multiply(self.rotation);
        return zm.Vec3f{ rotated.x, rotated.y, rotated.z };
    }

    pub fn bodyToWorldSpace(self: *const PhysicsBody, point: zm.Vec3f) zm.Vec3f {
        const inverseOrient = self.rotation.inverse();
        const quaternionVector = zm.Quaternionf.fromVec3(0.0, point);
        const rotated = self.rotation.multiply(quaternionVector).multiply(inverseOrient);
        return self.centerOfMassWorldSpace() + rotated;
    }
};

pub const World = struct {
    bodies: std.ArrayList(PhysicsBody),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .bodies = .{},
            .allocator = allocator,
        };
    }

    pub fn createBody(self: *World, transform: *Transform) !*PhysicsBody {
        try self.bodies.append(self.allocator, .{ .transform = transform });
        return &self.bodies.items[self.bodies.items.len - 1];
    }

    pub fn update(self: *World, dt: f32) void {
        for (self.bodies.items) |*b| {
            b.linearVelocity += zm.vec.scale(zm.Vec3f {0.0, GRAVITY, 0.0}, dt);
            b.transform.position += zm.vec.scale(b.linearVelocity, dt);

            if (b.transform.position[1] <= 0.0) {
                b.transform.position[1] = 0.0;
                b.linearVelocity[1] = 0.0;
            }
        }
    }
};

const std = @import("std");
const zm = @import("zm");

const Entity = usize;

pub const Transform = struct {
    position: zm.Vec3f = zm.vec.zero(3, f32),
    rotationQuat: zm.Quaternionf = zm.Quaternionf.identity(),
    rotationAngle: zm.Vec3f = zm.vec.zero(3, f32),
    scale: zm.Vec3f = zm.Vec3f{ 1.0, 1.0, 1.0 },
};

const Components = struct {
    transform: ?Transform = null,
};

pub const ECS = struct {
    table: std.MultiArrayList(Components),

    pub fn create(self: *ECS, allocator: std.mem.Allocator) !Entity {
        try self.table.addOne(allocator);
        return self.table.len;
    }
};

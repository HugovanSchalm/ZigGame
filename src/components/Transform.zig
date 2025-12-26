const zm = @import("zm");

const Transform = @This();

position: zm.Vec3f = zm.vec.zero(3, f32),
rotation: zm.Quaternionf = .identity(),
scale: zm.Vec3f = .{ 1.0, 1.0, 1.0 }

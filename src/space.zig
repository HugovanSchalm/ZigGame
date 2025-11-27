const zm = @import("zm");


pub const Transform = struct {
    const Position = zm.Vec3f;
    const Rotation = zm.Quaternionf;
    const Scale = zm.Vec3f;

    position: Position = zm.vec.zero(3, f32),
    rotation: Rotation = zm.Quaternionf.identity(),
    scale: Scale = .{ 1.0, 1.0, 1.0 },

    pub fn getMatrix(self: Transform) zm.Mat4f {
        return 
            zm.Mat4f.translationVec3(self.position)
            .multiply(zm.Mat4f.fromQuaternion(self.rotation))
            .multiply(zm.Mat4f.scalingVec3(self.scale));
    }
};

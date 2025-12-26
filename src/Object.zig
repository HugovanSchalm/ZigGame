const std = @import("std");
const Model = @import("model.zig").Model;
const zm = @import("zm");
const c = @import("c.zig").imports;
const physics = @import("physics.zig");
const Transform = @import("components/Transform.zig");

const Object = @This();

allocator: std.mem.Allocator,
name: [:0]const u8,
model: *Model,
transform: Transform = .{},
showDebug: bool = true,

pub fn render(self: *Object) void {
    if (self.showDebug) {
        _ = c.ImGui_Begin(@ptrCast(self.name), &self.showDebug, c.ImGuiWindowFlags_None);
        _ = c.ImGui_DragFloat3Ex(
            "Position",
            @ptrCast(&self.transform.position),
            0.1,
            -100.0,
            100.0,
            null,
            c.ImGuiSliderFlags_None,
        );
        _ = c.ImGui_DragFloat3Ex(
            "Scale",
            @ptrCast(&self.transform.scale),
            0.1,
            0.1,
            100.0,
            null,
            c.ImGuiSliderFlags_None,
        );
        // TODO: Implement rotation in UI
        // _ = c.ImGui_DragFloat3Ex(
        //     "rotation",
        //     @ptrCast(&self.transform.rotationAngle),
        //     1.0,
        //     0.0,
        //     360.0,
        //     null,
        //     c.ImGuiSliderFlags_WrapAround,
        // );
        // self.transform.rotation = 
        //     zm.Quaternionf.fromAxisAngle(zm.vec.forward(f32), std.math.degreesToRadians(self.transform.rotationAngle[0]))
        //     .multiply(zm.Quaternionf.fromAxisAngle(zm.vec.up(f32), std.math.degreesToRadians(self.transform.rotationAngle[1])))
        //     .multiply(zm.Quaternionf.fromAxisAngle(zm.vec.right(f32), std.math.degreesToRadians(self.transform.rotationAngle[2]))).conjugate();
        c.ImGui_End();
    }
    const postionMat = zm.Mat4f.translationVec3(self.transform.position);
    const rotationMat = zm.Mat4f.fromQuaternion(self.transform.rotation);
    const scaleMat = zm.Mat4f.scalingVec3(self.transform.scale);
    const modelMat = postionMat.multiply(rotationMat.multiply(scaleMat));
    self.model.shader.setMat4f("model", &modelMat);
    self.model.render();
}

pub fn init(allocator: std.mem.Allocator, model: *Model, name: [:0]const u8) !Object {
    return Object{
        .allocator = allocator,
        .name = name,
        .model = model,
    };
}

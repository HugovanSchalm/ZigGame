const std = @import("std");
const Model = @import("model.zig").Model;
const zm = @import("zm");
const c = @import("c.zig").imports;

pub const Transform = struct {
    position: zm.Vec3f = zm.vec.zero(3, f32),
    rotation: zm.Quaternionf = zm.Quaternionf.identity(),
    scale: zm.Vec3f = zm.Vec3f{ 1.0, 1.0, 1.0 },
};

pub const Object = struct {
    model: Model,
    transform: Transform = .{},
    showDebug: bool = true,

    pub fn render(self: *Object) void {
        if (self.showDebug) {
            _ = c.ImGui_Begin("Object", &self.showDebug, c.ImGuiWindowFlags_None);
            _ = c.ImGui_DragFloat3Ex(
                "Position",
                @ptrCast(&self.transform.position),
                0.1,
                -100.0,
                100.0,
                null,
                c.ImGuiSliderFlags_None,
            );
            c.ImGui_End();
        }
        const postionMat = zm.Mat4f.translationVec3(self.transform.position);
        const rotationMat = zm.Mat4f.fromQuaternion(self.transform.rotation);
        const scaleMat = zm.Mat4f.scalingVec3(self.transform.scale);
        const modelMat = postionMat.multiply(rotationMat.multiply(scaleMat));
        self.model.shader.setMat4f("model", &modelMat);
        self.model.render();
    }
};

pub const ObjectManager = struct {
    objects: std.AutoArrayHashMap(usize, Object),

    pub fn init(allocator: std.mem.Allocator) ObjectManager {
        const objects = std.AutoArrayHashMap(usize, Object).init(allocator);
        return ObjectManager {
            .objects = objects,
        };
    }

    pub fn insert(self: *ObjectManager, model: Model) usize {
        const S = struct {
            var nextid: usize = 1;
        };

        const object = Object {
            .model = model,
        };

        const id = S.nextid;
        S.nextid += 1;
        self.objects.put(id, object);

        return id;
    }

    pub fn get(self: ObjectManager, id: usize) ?*Object {
        return self.objects.getPtr(id);
    }

    pub fn renderAll(self: ObjectManager) void {
        for (self.objects.items) |object| {
            object.render();
        }
    }
};

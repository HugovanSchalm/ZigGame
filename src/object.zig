const std = @import("std");
const Model = @import("model.zig").Model;
const zm = @import("zm");
const c = @import("c.zig").imports;

const ObjectID = u64;

pub const Transform = struct {
    position: zm.Vec3f = zm.vec.zero(3, f32),
    rotation: zm.Quaternionf = zm.Quaternionf.identity(),
    scale: zm.Vec3f = zm.Vec3f{ 1.0, 1.0, 1.0 },
};

pub const Object = struct {
    id: ObjectID,
    name: [:0]const u8,
    model: *Model,
    transform: Transform = .{},
    showDebug: bool = true,

    pub fn render(self: *Object) void {
        if (self.showDebug) {
            std.io.getStdOut().writer().print("{s}\n", .{self.name}) catch {};
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
    allocator: std.mem.Allocator,
    objects: std.AutoArrayHashMap(usize, Object),

    pub fn init(allocator: std.mem.Allocator) ObjectManager {
        const objects = std.AutoArrayHashMap(usize, Object).init(allocator);
        return ObjectManager{
            .allocator = allocator,
            .objects = objects,
        };
    }

    pub fn deinit(self: *ObjectManager) void {
        self.objects.deinit();
    }

    pub fn createObject(self: *ObjectManager, model: *Model) !*Object {
        const id = try self.insert(model);
        return self.objects.getPtr(id).?;
    }

    pub fn insert(self: *ObjectManager, model: *Model) !u64 {
        const S = struct {
            var nextid: ObjectID = 1;
        };

        const id = S.nextid;
        S.nextid += 1;

        const name = try std.fmt.allocPrintZ(self.allocator, "Object {d}", .{id});

        const object = Object{
            .id = id,
            .name = name,
            .model = model,
        };

        try self.objects.put(id, object);

        return id;
    }

    pub fn get(self: ObjectManager, id: ObjectID) ?*Object {
        return self.objects.getPtr(id);
    }

    pub fn renderAll(self: ObjectManager) void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.render();
        }
    }
};

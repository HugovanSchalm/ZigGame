const std = @import("std");
const Model = @import("model.zig").Model;
const zm = @import("zm");
const c = @import("c.zig").imports;
const physics = @import("physics.zig");

const ObjectID = u64;

pub const Object = struct {
    allocator: std.mem.Allocator,
    id: ObjectID,
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
            _ = c.ImGui_DragFloat3Ex(
                "rotation",
                @ptrCast(&self.transform.rotationAngle),
                1.0,
                0.0,
                360.0,
                null,
                c.ImGuiSliderFlags_WrapAround,
            );
            self.transform.rotationQuat = 
                zm.Quaternionf.fromAxisAngle(zm.vec.forward(f32), std.math.degreesToRadians(self.transform.rotationAngle[0]))
                .multiply(zm.Quaternionf.fromAxisAngle(zm.vec.up(f32), std.math.degreesToRadians(self.transform.rotationAngle[1])))
                .multiply(zm.Quaternionf.fromAxisAngle(zm.vec.right(f32), std.math.degreesToRadians(self.transform.rotationAngle[2]))).conjugate();
            c.ImGui_End();
        }
        const postionMat = zm.Mat4f.translationVec3(self.transform.position);
        const rotationMat = zm.Mat4f.fromQuaternion(self.transform.rotationQuat);
        const scaleMat = zm.Mat4f.scalingVec3(self.transform.scale);
        const modelMat = postionMat.multiply(rotationMat.multiply(scaleMat));
        self.model.shader.setMat4f("model", &modelMat);
        self.model.render();
    }

    fn init(allocator: std.mem.Allocator, model: *Model) !Object {
        const S = struct {
            var nextid: ObjectID = 1;
        };
        const id = S.nextid;
        S.nextid += 1;

        const name = try std.fmt.allocPrintSentinel(allocator, "Object {d}", .{id}, 0);

        return Object{
            .allocator = allocator,
            .id = id,
            .name = name,
            .model = model,
        };
    }

    fn deinit(self: *Object) void {
        self.allocator.free(self.name);
    }
};

pub const ObjectManager = struct {
    allocator: std.mem.Allocator,
    objects: std.AutoArrayHashMap(ObjectID, Object),
    physicsBodies: std.AutoArrayHashMap(ObjectID, physics.PhysicsBody),

    pub fn init(allocator: std.mem.Allocator) ObjectManager {
        const objects = std.AutoArrayHashMap(ObjectID, Object).init(allocator);
        const physicsBodies = std.AutoArrayHashMap(ObjectID, physics.PhysicsBody).init(allocator);
        return ObjectManager{
            .allocator = allocator,
            .objects = objects,
            .physicsBodies = physicsBodies,
        };
    }

    pub fn deinit(self: *ObjectManager) void {
        for (self.objects.values()) |*object| {
            object.deinit();
        }
        self.objects.deinit();
        self.physicsBodies.deinit();
    }

    ///Returns the id instead of a pointer as the object might move during execution
    pub fn create(self: *ObjectManager, model: *Model) !u64 {
        const object = try Object.init(self.allocator, model);
        try self.objects.put(object.id, object);

        return object.id;
    }

    pub fn attachPhysicsBody(self: *ObjectManager, objectId: ObjectID) !void {
        if (!self.objects.contains(objectId)) {
            return error.ObjectNotFound;
        }

        const body = physics.PhysicsBody.init(2.0, 2.0);
        try self.physicsBodies.put(objectId, body);
    }

    pub fn get(self: ObjectManager, id: ObjectID) ?*Object {
        return self.objects.getPtr(id);
    }

    pub fn getAll(self: ObjectManager) []Object {
        return self.objects.values();
    }

    pub fn updatePhysics(self: ObjectManager, dt: f32) void {
        for (self.physicsBodies.keys()) |id| {
            const body = self.physicsBodies.getPtr(id).?;
            body.applyGravity(dt);

            const object = self.objects.getPtr(id).?;
            body.updateObject(object, dt);
        }
    }

    pub fn renderAll(self: ObjectManager) void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.render();
        }
    }
};

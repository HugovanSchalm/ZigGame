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
    inverseMass: f32 = 1.0,
    elasticity: f32 = 1.0,

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

    pub fn applyImpulse(self: *PhysicsBody, impulse: zm.Vec3f) void {
        if (self.inverseMass == 0.0) {
            return;
        }

        self.linearVelocity += zm.vec.scale(impulse, self.inverseMass);
    }

    pub fn intersects(self: *PhysicsBody, other: *PhysicsBody, contact: *Contact) bool {
        contact.bodyA = self;
        contact.bodyB = other;

        const ab = other.transform.position - self.transform.position;

        contact.normal = zm.vec.normalize(ab);

        const selfSphere = self.shape.shapeType.sphere;
        const otherSphere = other.shape.shapeType.sphere;

        contact.WorldA = self.transform.position + zm.vec.scale(contact.normal, selfSphere.radius);
        contact.WorldB = other.transform.position - zm.vec.scale(contact.normal, otherSphere.radius);

        const radiusAB = selfSphere.radius + otherSphere.radius;
        const lengthSquare = zm.vec.lenSq(ab);

        if (!std.math.isNan(ab[0])) {
            std.debug.print("{any}\n", .{other.transform.position});
            std.debug.print("{any}\n", .{self.transform.position});
            std.debug.print("{any}\n", .{ab});
            std.debug.print("{any}\n", .{lengthSquare});
            std.debug.print("{any}\n", .{radiusAB});

            std.debug.print("\n", .{});
        }

        return lengthSquare <= (radiusAB * radiusAB);
    }
};

const Contact = struct {
    WorldA: zm.Vec3f = zm.vec.zero(3, f32),
    WorldB: zm.Vec3f = zm.vec.zero(3, f32),
    LocalA: zm.Vec3f = zm.vec.zero(3, f32),
    LocalB: zm.Vec3f = zm.vec.zero(3, f32),
    normal: zm.Vec3f = zm.vec.zero(3, f32),
    seperationDistance: f32 = 0.0,
    timeOfImpact: f32 = 0.0,

    bodyA: ?*PhysicsBody = null,
    bodyB: ?*PhysicsBody = null,

    pub fn resolve(self: *Contact) void {
        const bodyA = self.bodyA orelse return;
        const bodyB = self.bodyB orelse return;
        const elasticity = bodyA.elasticity * bodyB.elasticity;

        const vab = bodyA.linearVelocity - bodyB.linearVelocity;
        const impulseJ = -(1.0 + elasticity) * zm.vec.dot(vab, self.normal) / (bodyA.inverseMass + bodyB.inverseMass);
        const vectorImpulseJ = zm.vec.scale(self.normal, impulseJ);

        bodyA.applyImpulse(vectorImpulseJ);
        bodyB.applyImpulse(zm.vec.scale(vectorImpulseJ, -1.0));

        const tA = bodyA.inverseMass / (bodyA.inverseMass + bodyB.inverseMass);
        const tB = bodyB.inverseMass / (bodyA.inverseMass + bodyB.inverseMass);

        const ds = self.WorldB - self.WorldA;
        bodyA.transform.position += zm.vec.scale(ds, tA);
        bodyB.transform.position -= zm.vec.scale(ds, tB);
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

    pub fn deinit(self: *World) void {
        self.bodies.deinit(self.allocator);
    }

    pub fn createBody(self: *World, transform: *Transform) !*PhysicsBody {
        try self.bodies.append(self.allocator, .{ .transform = transform });
        return &self.bodies.items[self.bodies.items.len - 1];
    }

    pub fn update(self: *World, dt: f32) void {
        // Forces
        for (self.bodies.items) |*b| {
            const gravityForce = zm.Vec3f{ 0.0, GRAVITY, 0.0 };
            const mass = 1.0 / b.inverseMass;
            const impulse = zm.vec.scale(gravityForce, mass * dt);
            b.applyImpulse(impulse);
        }

        // Collisions
        for (self.bodies.items, 0..) |*body, i| {
            for (self.bodies.items, 0..) |*other, j| {
                // TODO should be removable
                if (i == j) {
                    continue;
                }

                if (body.inverseMass == 0.0 and other.inverseMass == 0.0) {
                    continue;
                }

                var contact: Contact = .{};
                if (body.intersects(other, &contact)) {
                    contact.resolve();
                }
            }
        }

        for (self.bodies.items) |*b| {
            b.transform.position += zm.vec.scale(b.linearVelocity, dt);
        }
    }
};

//! Aggregates the struct and the by_language stuff.
const std = @import("std");
const testing = std.testing;

pub const Owner = struct {
    login: []const u8,
};

pub const Repo = struct {
    name: []const u8,
    owner: Owner,
    description: ?[]const u8,
    topics: [][]const u8,
    language: ?[]const u8,
};

pub fn GroupBy(comptime T: type, keyFn: *const fn (*const T) []const u8) type {
    if (@typeInfo(T) != .@"struct") {
        @compileError("Expected struct type for group by" ++ @tagName(@typeInfo(T)));
    }
    return struct {
        const Self = @This();
        map: std.StringHashMap(std.ArrayList(*Repo)),
        allocator: std.mem.Allocator,
        arena: std.heap.ArenaAllocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .map = std.StringHashMap(std.ArrayList(*Repo)).init(allocator),
                .allocator = allocator,
                .arena = std.heap.ArenaAllocator.init(allocator),
            };
        }

        /// Returns a StringHashMap managed by GroupBy. In case elements T can't give a []u8 key.
        pub fn group(self: *Self, items: *const []T) !*std.StringHashMap(std.ArrayList(*Repo)) {
            const arenaAlloc = self.arena.allocator();
            for (items.*) |*item| {
                const key = keyFn(item);
                const gop = try self.map.getOrPut(key);
                if (!gop.found_existing) {
                    var arr = std.ArrayList(*Repo).init(arenaAlloc);
                    errdefer arr.deinit();
                    try arr.append(item);
                    gop.value_ptr.* = arr;
                } else {
                    try gop.value_ptr.*.append(item);
                }
            }
            return &self.map;
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
            self.arena.deinit();
        }
    };
}

pub fn getKey(r: *const Repo) []const u8 {
    return r.language orelse "Not-Set";
}

pub fn getKey2(_: *const u32) []const u8 {
    return "Not-Set";
}

test "byLanguage works" {
    const allocator = std.testing.allocator;

    var repos = [_]Repo{
        .{
            .name = "repo1",
            .language = "zig",
            .owner = Owner{ .login = "ps" },
            .topics = undefined,
            .description = "sample",
        },
        .{
            .name = "repo2",
            .language = "rust",
            .owner = Owner{ .login = "ps" },
            .topics = undefined,
            .description = "sample",
        },
        .{
            .name = "repo3",
            .language = "rust",
            .owner = Owner{ .login = "ps" },
            .topics = undefined,
            .description = "sample",
        },
    };
    const repo_slice: []Repo = repos[0..];

    {
        var groupBy = GroupBy(Repo, getKey).init(allocator);
        defer groupBy.deinit();

        const groupped = try groupBy.group(&repo_slice);
        try std.testing.expectEqual(@as(usize, 2), groupped.count());
        try std.testing.expect(groupped.contains("rust"));
        try std.testing.expectEqual(@as(usize, 2), groupped.get("rust").?.items.len);
        try std.testing.expect(groupped.contains("zig"));
    }

    try std.testing.expectEqual(repo_slice[0].name, "repo1");
}

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
    topics: [][]u8,
    language: ?[]const u8,
};

pub fn GroupBy(comptime T: type, keyFn: fn (*T) []const u8) type {
    return struct {
        const Self = @This();
        map: std.StringHashMap([]*T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .map = std.StringHashMap([]*T).init(allocator),
                .allocator = allocator,
            };
        }

        /// Returns a StringHashMap managed by GroupBy. In case elements T can't give a []u8 key.
        pub fn group(self: *Self, items: *const []T) !*std.StringHashMap([]*T) {
            for (items.*) |*item| {
                const key = keyFn(item);
                const gop = try self.map.getOrPut(key);
                if (!gop.found_existing) {
                    // Allocate a slice of one repo pointer for new languages
                    gop.value_ptr.* = try self.allocator.alloc(*T, 1);
                    gop.value_ptr.*[0] = item; // repo is now a pointer
                } else {
                    // Extend the existing slice of repo pointers
                    const current_slice = gop.value_ptr.*;
                    var new_slice = try self.allocator.realloc(current_slice, current_slice.len + 1);
                    new_slice[current_slice.len] = item; // repo is now a pointer
                    gop.value_ptr.* = new_slice;
                }
            }

            return &self.map;
        }

        pub fn deinit(self: *Self) void {
            var iter = self.map.iterator();
            while (iter.next()) |e| {
                self.allocator.free(e.value_ptr.*);
            }
            self.map.deinit();
        }
    };
}

pub fn getKey(r: *Repo) []const u8 {
    return r.language orelse "Not-Set";
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

    var groupBy = GroupBy(Repo, getKey).init(allocator);
    defer groupBy.deinit();

    const repo_slice: []Repo = repos[0..];

    const groupped = try groupBy.group(&repo_slice);

    try std.testing.expectEqual(@as(usize, 2), groupped.count());
}

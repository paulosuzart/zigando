const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const PrefixTreeError = error{
    KeyAlreadyExists,
};

pub fn PrefixTree(comptime V: type) type {
    return struct {
        /// Root node of the tree.
        root: *Node,
        allocator: std.mem.Allocator,

        const Self = @This();

        const Node = struct {
            /// The character of this node itself
            character: u8,
            /// If any, holds the string
            word: ?[]const u8,
            /// The nodes that follow from this prefix
            children: std.AutoHashMap(u8, *Node),
            value: ?V,

            fn init(allocator: std.mem.Allocator, c: u8) anyerror!Node {
                return Node{
                    .character = c,
                    .children = std.AutoHashMap(u8, *Node).init(allocator),
                    .word = null,
                    .value = undefined,
                };
            }

            fn deinit(self: *Node, allocator: std.mem.Allocator) void {
                var it = self.children.iterator();
                while (it.next()) |e| {
                    e.value_ptr.*.deinit(allocator);
                    allocator.destroy(e.value_ptr.*);
                }
                self.children.deinit();
            }
        };

        fn init(allocator: std.mem.Allocator) !Self {
            const root = try allocator.create(Node);
            root.* = try Node.init(allocator, 0);
            return Self{
                .root = root,
                .allocator = allocator,
            };
        }

        fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
            self.allocator.destroy(self.root);
        }

        pub fn insert(self: *Self, word: []const u8, value: V) anyerror!void {
            var node = self.root;
            for (word) |c| {
                if (node.children.get(c)) |child| {
                    node = child;
                } else {
                    const newNode = try self.allocator.create(Node);
                    newNode.* = try Node.init(self.allocator, c);
                    newNode.value = value;
                    try node.children.put(c, newNode);
                    node = newNode;
                }
            }
            // TODO Use a hashmap in case the tree is too big?
            if (node.word) |existing_word| {
                if (std.mem.eql(u8, existing_word, word)) {
                    return PrefixTreeError.KeyAlreadyExists;
                }
            }
            node.word = word;
        }

        // TODO Return a reference to the future type V
        pub fn search(self: *Self, word: []const u8) ?V {
            var node = self.root;
            for (word) |c| {
                if (node.children.get(c)) |child| {
                    node = child;
                }
            }
            if (node.word) |found_word| {
                if (std.mem.eql(u8, found_word, word)) {
                    return node.value;
                }
            }
            return null;
        }
    };
}

const Person = struct {
    name: []const u8,
};

test "Prefix works" {
    const allocator = std.testing.allocator;
    var pt = try PrefixTree(Person).init(allocator);

    defer pt.deinit();

    try pt.insert("saliva", Person{ .name = "Jorge" });
    try pt.insert("salvia", Person{ .name = "Angelo" });
    pt.insert("salvia", Person{ .name = "Abdon" }) catch |err| {
        try std.testing.expectEqual(@errorName(PrefixTreeError.KeyAlreadyExists), @errorName(err));
    };
    try pt.insert("sarcastic", Person{ .name = "Mathias" });

    if (pt.search("sarcastic")) |found| {
        const toFind = Person{ .name = "Mathias" };
        try std.testing.expectEqualStrings(toFind.name, found.name);
    }
}

test "Prefix works for pointers" {
    const allocator = std.testing.allocator;
    var pt = try PrefixTree(*const Person).init(allocator);

    defer pt.deinit();
    const sandra = Person{ .name = "Sandra" };
    try pt.insert("keyA", &sandra);

    if (pt.search("keyA")) |found| {
        try std.testing.expectEqualStrings(sandra.name, found.*.name);
    }
}

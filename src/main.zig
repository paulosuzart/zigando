//! A simple test that creates a http client, fetches the first page of starred items for a given user
//! and prints each repo with their topics, as well as each language and the amount of repos for that language.
//! Sample output:
//! Repo name is gluesql/gluesql ({ database, nosql, rust, schemaless, sql, storage, webassembly, websql })
//! Repo name is efugier/smartcat ({ ai, chatgpt, cli, command-line, command-line-tool, copilot, llm, mistral-ai, unix })
//! Repo name is regolith-labs/steel ({ solana })
//! Language Rust: 13 repos
//! Language Zig: 2 repos
//! Language Jupyter Notebook: 1 repos
//! Language HTML: 1 repos
//! ...
const std = @import("std");
const lib = @import("root.zig");
const GithubStarredAPI = @import("github.zig").GithubStarredAPI;

const Location = std.http.Client.FetchOptions.Location;
const URI = "https://api.github.com/user/starred";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // gets the token from the env
    const token = std.posix.getenv("TOKEN") orelse {
        std.log.err("Please provide a TOKEN env", .{});
        return;
    };
    // creates the bearer
    const bearer = try std.fmt.allocPrint(allocator, "Bearer {s}", .{token});
    defer allocator.free(bearer);

    // allocates the http client
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var starredApi = GithubStarredAPI().init(allocator, bearer, &client);

    const repos = try starredApi.fetchFirstPage();
    defer repos.deinit();
    std.debug.print("{} Repos returned\n", .{repos.value.len});

    for (repos.value) |r| {
        std.debug.print("Repo name is {s}/{s} ({s})\n", .{
            r.owner.login,
            r.name,
            r.topics,
        });
    }

    var groupBy = lib.GroupBy(lib.Repo, lib.getKey).init(allocator);
    defer groupBy.deinit();

    var groupped = try groupBy.group(&repos.value);

    var langIter = groupped.iterator();

    while (langIter.next()) |g| {
        std.debug.print("Language {s}: {d} repos\n", .{ g.key_ptr.*, g.value_ptr.*.items.len });
    }
}

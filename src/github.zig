const std = @import("std");
const lib = @import("root.zig");

const Allocator = std.mem.Allocator;
const Client = std.http.Client;
const Location = std.http.Client.FetchOptions.Location;
const FetchOptions = std.http.Client.FetchOptions;
const Headers = std.http.Client.Request.Headers;
const Uri = std.Uri;

const GET = std.http.Method.GET;
const URI = "https://api.github.com/user/starred";

pub const HttpError = error{
    FetchError,
};

pub const GithubError = error{
    JsonParseError,
    NonOkResponse,
};

pub const StarredApiError = HttpError || GithubError;

/// A Starred API client. Taks the bearer token and the http client.
pub fn GithubStarredAPI() type {
    return struct {
        const Self = @This();
        allocator: Allocator,
        uri: std.Uri,
        bearerToken: []const u8,
        client: *Client,

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.uri);
            self.allocator.free(self.bearerToken);
        }

        pub fn init(allocator: Allocator, bearerToken: []const u8, client: *Client) Self {
            return .{
                .bearerToken = bearerToken,
                .client = client,
                .allocator = allocator,
                .uri = Uri.parse(URI) catch unreachable,
            };
        }

        // Parsed result must be managed by the call site.
        pub fn fetchFirstPage(self: *Self) StarredApiError!std.json.Parsed([]lib.Repo) {
            var respStorage = std.ArrayList(u8).init(self.allocator);
            defer respStorage.deinit();
            const opts = FetchOptions{
                .location = Location{ .uri = self.uri },
                .method = GET,
                .headers = Headers{ .authorization = .{ .override = self.bearerToken } },
                .response_storage = .{ .dynamic = &respStorage },
            };

            const res = self.client.fetch(opts) catch {
                return StarredApiError.FetchError;
            };

            if (res.status != std.http.Status.ok) {
                std.debug.print("Error general: {s}", .{respStorage.items});
                return StarredApiError.NonOkResponse;
            }

            const parsed = std.json.parseFromSlice([]lib.Repo, self.allocator, respStorage.items, .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            }) catch {
                return StarredApiError.JsonParseError;
            };
            return parsed;
        }
    };
}

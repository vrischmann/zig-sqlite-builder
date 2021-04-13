const std = @import("std");
const download = @import("download");
usingnamespace std.build;

const Self = @This();
const name = "sqlite3";

pub const version = std.build.Version{
    .major = 3,
    .minor = 35,
    .patch = 2,
};

pub const LinkType = enum {
    system,
    static,
    shared,
};

config: ?struct {
    arena: std.heap.ArenaAllocator,
    lib: *LibExeObjStep,
    include_dir: []const u8,
},

pub fn init(
    b: *Builder,
    target: Target,
    mode: std.builtin.Mode,
    link_type: LinkType,
) !Self {
    return if (link_type == .system)
        Self{ .config = null }
    else blk: {
        var arena = std.heap.ArenaAllocator.init(b.allocator);
        errdefer arena.deinit();

        const allocator = &arena.allocator;
        const base_path = try download.tar.gz(
            allocator,
            b.cache_root,
            "https://www.sqlite.org/2021/sqlite-autoconf-3350400.tar.gz",
            .{},
        );

        const lib = if (link_type == .static)
            b.addStaticLibrary(name, null)
        else
            b.addSharedLibrary(name, null, .{ .versioned = version });

        for (srcs) |src| {
            lib.addCSourceFile(try std.fs.path.join(allocator, &[_][]const u8{
                base_path, src,
            }), &[_][]const u8{});
        }

        lib.addIncludeDir(base_path);
        lib.setTarget(target);
        lib.setBuildMode(mode);
        lib.linkLibC();
        break :blk Self{
            .config = .{
                .arena = arena,
                .lib = lib,
                .include_dir = base_path,
            },
        };
    };
}

pub fn deinit(self: *Self) void {
    if (self.config) |config| {
        config.arena.deinit();
    }
}

pub fn link(self: Self, other: *LibExeObjStep) void {
    if (self.config) |config| {
        other.linkLibrary(config.lib);
        other.addIncludeDir(config.include_dir);
    } else {
        other.linkSystemLibrary("sqlite3");
        other.linkLibC();
    }
}

const srcs = [_][]const u8{
    "sqlite3.c",
};

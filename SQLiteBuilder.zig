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

pub const ThreadSafety = enum {
    single_threaded,
    serialized,
    multi_threaded,

    fn toCompileParameter(self: @This()) []const u8 {
        return switch (self) {
            .single_threaded => "-DSQLITE_THREADSAFE=0",
            .serialized => "-DSQLITE_THREADSAFE=1",
            .multi_threaded => "-DSQLITE_THREADSAFE=2",
        };
    }
};

pub const Options = struct {
    link_type: LinkType = .system,
    thread_safety: ThreadSafety = .serialized,
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
    options: Options,
) !Self {
    return if (options.link_type == .system)
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

        const lib = if (options.link_type == .static)
            b.addStaticLibrary(name, null)
        else
            b.addSharedLibrary(name, null, .{ .versioned = version });

        for (srcs) |src| {
            const flags = &[_][]const u8{
                options.thread_safety.toCompileParameter(),
            };

            lib.addCSourceFile(
                try std.fs.path.join(allocator, &[_][]const u8{
                    base_path, src,
                }),
                flags,
            );
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

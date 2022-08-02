const std = @import("std");
const download = @import("download");

const Self = @This();
const name = "sqlite3";

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

    version_year: usize = 2022,
    version: std.builtin.Version = .{
        .major = 3,
        .minor = 39,
        .patch = 2,
    },
};

config: ?struct {
    arena: std.heap.ArenaAllocator,
    lib: *std.build.LibExeObjStep,
    include_dir: []const u8,
},

pub fn init(
    b: *std.build.Builder,
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
    options: Options,
) !Self {
    return if (options.link_type == .system)
        Self{ .config = null }
    else blk: {
        var arena = std.heap.ArenaAllocator.init(b.allocator);
        errdefer arena.deinit();

        const allocator = &arena.allocator;

        const url = blk2: {
            var buf: [2048]u8 = undefined;

            break :blk2 try std.fmt.bufPrint(&buf, "https://www.sqlite.org/{d}/sqlite-autoconf-{d}{d:0>2}{d:0>2}00.tar.gz", .{
                options.version_year,
                options.version.major,
                options.version.minor,
                options.version.patch,
            });
        };

        const base_path = try download.tar.gz(allocator, b.cache_root, url, .{});

        const lib = if (options.link_type == .static)
            b.addStaticLibrary(name, null)
        else
            b.addSharedLibrary(name, null, .{ .versioned = options.version });

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

pub fn link(self: Self, other: *std.build.LibExeObjStep) void {
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

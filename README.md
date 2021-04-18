# zig-sqlite-builder

# Introduction

Using the stuff in `std.build.Builder` you can very easily build sqlite and embed it into your application, no linking required.

This is great but it does require the user to get the sqlite C source code somehow and add the appropriate calls to build the object.

This repository intends to simplify this.

# Usage

Right now this repository has only been tested with [gyro](https://github.com/mattnite/gyro) (_mattnite_ also came up with the idea of [using builder](https://github.com/mattnite/ZLibBuilder), thanks to him).

# Add the package to gyro

Add this to your `gyro.zzz`:
```
build_deps:
  sqlite-builder:
    src:
      github:
        user: vrischmann
        repo: zig-sqlite-builder
        ref: master
    root: SQLiteBuilder.zig
```

This makes the `sqlite-builder` package importable from the `build.zig` file, which is what we want.

# Configuring build.zig

This repository provides the `SQLiteBuilder.init` function which is responsible for configuring the sqlite build.

You use it like this in your `build.zig` file:
```zig
pub fn build(b: *std.build.Builder) !void {
    ...

    const sqlite_link_type = b.option(SQLiteBuilder.LinkType, "sqlite_link", "how you want to link to sqlite") orelse .shared;

    var sqlite_builder = try SQLiteBuilder.init(b, target, mode, sqlite_link_type);
    defer sqlite_builder.deinit();

    const exe = b.addExecutable("foobar", "src/main.zig");
    sqlite_builder.link(exe);

    ...
}
```

And that's it, you now have a build option allowing you to control how sqlite is linked:
* `static` builds sqlite from the upstream source code and links it statically
* `shared` builds sqlite from the upstream source code as a shared library (which you'll need to ship)
* `system` doesn't build sqlite at all, instead links against the system library (which you'll need to install)

# Caveats

This is relatively barebones for now but one can imagine adding more functionality like enabling/disabling multithreading support in sqlite,
or tuning one of the dozens of compile-time options available in sqlite.

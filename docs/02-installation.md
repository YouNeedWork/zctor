# Installation

This guide covers different ways to install and set up zctor in your project.

## Requirements

- **Zig**: Version 0.14.0 or higher
- **libxev**: Automatically managed as a dependency

## Installation Methods

### Option 1: From Source

Clone the repository and build from source:

```bash
git clone https://github.com/YouNeedWork/zctor.git
cd zctor
zig build
```

### Option 2: Using as a Library

Add zctor as a dependency to your Zig project.

#### Step 1: Add to build.zig.zon

Add zctor to your project's `build.zig.zon` dependencies:

```zig
.dependencies = .{
    .zctor = .{
        .url = "https://github.com/YouNeedWork/zctor/archive/main.tar.gz",
        .hash = "1220...", // Use zig fetch to get the correct hash
    },
},
```

#### Step 2: Configure build.zig

In your project's `build.zig`, add zctor as a dependency:

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add zctor dependency
    const zctor_dep = b.dependency("zctor", .{ 
        .target = target, 
        .optimize = optimize 
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import zctor module
    exe.root_module.addImport("zctor", zctor_dep.module("zctor"));

    b.installArtifact(exe);
}
```

#### Step 3: Import in Your Code

Now you can import and use zctor in your Zig code:

```zig
const std = @import("std");
const zctor = @import("zctor");

const ActorEngine = zctor.ActorEngine;
const Actor = zctor.Actor;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();

    // Your actor code here...
}
```

## Verifying Installation

### Build Test

Verify that zctor builds correctly:

```bash
zig build
```

### Run Tests

Run the test suite to ensure everything is working:

```bash
zig build test
```

### Run Example

Try running the included example:

```bash
zig build run
```

You should see output similar to:
```
Actor Engine Started
Got Hello: World (count: 1, total_hellos: 1)
Got Ping: 42 (count: 2, total_pings: 1)
```

## Project Structure

After installation, your project structure should look like:

```
my-project/
├── build.zig
├── build.zig.zon
├── src/
│   └── main.zig
└── zig-cache/
    └── dependencies/
        └── zctor/
```

## Development Setup

### Editor Support

For the best development experience, use an editor with Zig language server support:

- **VS Code**: Install the official Zig extension
- **Vim/Neovim**: Use vim-zig or nvim-treesitter
- **Emacs**: Use zig-mode
- **IntelliJ**: Use the Zig plugin

### Debug Builds

For development, use debug builds:

```bash
zig build -Doptimize=Debug
```

### Release Builds

For production, use optimized builds:

```bash
zig build -Doptimize=ReleaseFast
```

## Troubleshooting

### Common Issues

#### Zig Version Mismatch

**Problem**: Build fails with compiler errors
**Solution**: Ensure you're using Zig 0.14.0 or higher:

```bash
zig version
```

#### Missing libxev

**Problem**: Linker errors related to libxev
**Solution**: libxev should be automatically fetched. Try:

```bash
zig build --fetch
```

#### Permission Errors

**Problem**: Cannot write to zig-cache
**Solution**: Ensure you have write permissions in your project directory

### Getting Help

If you encounter issues:

1. Check the [examples](./06-examples.md) for working code
2. Review the [API reference](./05-api-reference.md) for usage details
3. Open an issue on [GitHub](https://github.com/YouNeedWork/zctor/issues)

## Next Steps

Now that you have zctor installed, you're ready to:

- [Quick Start](./03-quick-start.md) - Build your first actor
- [Architecture](./04-architecture.md) - Understand the framework
- [Examples](./06-examples.md) - See practical implementations
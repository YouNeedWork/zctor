# Contributing

Welcome to the zctor contributor guide! This chapter explains how to contribute to the zctor project, from setting up your development environment to submitting your changes.

## Getting Started

### Development Environment Setup

1. **Install Zig**: Ensure you have Zig 0.14.0 or later installed:
   ```bash
   # Download from https://ziglang.org/download/
   # Or use your package manager
   ```

2. **Clone the Repository**:
   ```bash
   git clone https://github.com/YouNeedWork/zctor.git
   cd zctor
   ```

3. **Build and Test**:
   ```bash
   zig build
   zig build test
   zig build run
   ```

4. **Generate Documentation**:
   ```bash
   zig build docs
   ```

### Development Tools

**Recommended Editor Setup**:
- **VS Code**: Install the official Zig extension
- **Vim/Neovim**: Use `vim-zig` or `nvim-treesitter`
- **Emacs**: Use `zig-mode`

**Useful Commands**:
```bash
# Run with debug info
zig build -Doptimize=Debug

# Run specific tests
zig test src/actor.zig

# Format code
zig fmt src/

# Check for issues
zig build -Doptimize=ReleaseSafe
```

## Code Style Guidelines

### Naming Conventions

```zig
// Types: PascalCase
const ActorMessage = union(enum) { ... };
const DatabaseConnection = struct { ... };

// Functions and variables: camelCase
pub fn createConnection() !*DatabaseConnection { ... }
const messageCount: u32 = 0;

// Constants: SCREAMING_SNAKE_CASE
const MAX_CONNECTIONS: u32 = 100;
const DEFAULT_TIMEOUT_MS: u64 = 5000;

// Private fields: snake_case with leading underscore
const State = struct {
    _internal_counter: u32,
    public_data: []const u8,
};
```

### Code Organization

```zig
// File header comment
//! Brief description of the module
//! 
//! Longer description if needed
//! Multiple lines are okay

const std = @import("std");
const builtin = @import("builtin");

// Local imports
const Actor = @import("actor.zig").Actor;
const Context = @import("context.zig");

// Constants first
const DEFAULT_BUFFER_SIZE: usize = 4096;

// Types next
const MyStruct = struct {
    // Public fields first
    data: []const u8,
    
    // Private fields last
    _allocator: std.mem.Allocator,
    
    // Methods
    pub fn init(allocator: std.mem.Allocator) !*MyStruct { ... }
    
    pub fn deinit(self: *MyStruct) void { ... }
    
    // Private methods last
    fn internalMethod(self: *MyStruct) void { ... }
};

// Free functions last
pub fn utilityFunction() void { ... }
```

### Documentation Comments

```zig
/// Creates a new actor with the specified message type and handler.
/// 
/// The actor will be assigned to a thread automatically based on the
/// current load balancing strategy.
/// 
/// # Arguments
/// * `T` - The message type this actor will handle
/// * `handler` - Function to process messages of type T
/// 
/// # Returns
/// Returns an error if the actor cannot be created or if the maximum
/// number of actors has been reached.
/// 
/// # Example
/// ```zig
/// try engine.spawn(MyMessage, MyMessage.handle);
/// ```
pub fn spawn(self: *Self, comptime T: type, handler: fn (*Actor(T), T) ?void) !void {
    // Implementation
}

/// Actor state for message counting
const CounterState = struct {
    /// Number of messages processed
    count: u32 = 0,
    
    /// Timestamp of last message
    last_message_time: i64 = 0,
};
```

### Error Handling

```zig
// Define specific error types
const ActorError = error{
    InvalidMessage,
    ActorNotFound,
    ThreadPoolFull,
    StateCorrupted,
};

// Use explicit error handling
pub fn sendMessage(self: *Self, msg: anytype) ActorError!void {
    const thread = self.getAvailableThread() orelse return ActorError.ThreadPoolFull;
    
    thread.enqueueMessage(msg) catch |err| switch (err) {
        error.OutOfMemory => return ActorError.ThreadPoolFull,
        error.InvalidMessage => return ActorError.InvalidMessage,
        else => return err,
    };
}

// Handle errors at appropriate levels
pub fn handle(actor: *Actor(MyMessage), msg: MyMessage) ?void {
    processMessage(msg) catch |err| {
        std.log.err("Failed to process message: {}", .{err});
        return null; // Signal error to framework
    };
}
```

### Testing Patterns

```zig
const testing = std.testing;

test "Actor processes messages correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Setup
    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();
    
    // Test
    try engine.spawn(TestMessage, TestMessage.handle);
    
    var msg = TestMessage{ .Test = "hello" };
    try engine.send(TestMessage, &msg);
    
    // Verify (in a real test, you'd need better verification)
    try testing.expect(true);
}

test "Error handling works correctly" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var engine = try ActorEngine.init(allocator);
    defer engine.deinit();
    
    // Test error condition
    const result = engine.spawn(InvalidMessage, invalidHandler);
    try testing.expectError(error.InvalidMessage, result);
}
```

## Contribution Workflow

### 1. Create an Issue

Before starting work, create an issue to discuss:
- **Bug Reports**: Include reproduction steps, expected vs actual behavior
- **Feature Requests**: Describe the use case and proposed API
- **Documentation**: Identify gaps or improvements needed

**Bug Report Template**:
```markdown
## Bug Description
Brief description of the issue

## Reproduction Steps
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Zig version: 
- OS: 
- zctor version:

## Additional Context
Any other relevant information
```

### 2. Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/zctor.git
cd zctor
git remote add upstream https://github.com/YouNeedWork/zctor.git
```

### 3. Create a Branch

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Or a bugfix branch
git checkout -b fix/issue-123-description
```

### 4. Make Changes

- Write clean, well-documented code
- Add tests for new functionality
- Update documentation if needed
- Follow the code style guidelines

### 5. Test Your Changes

```bash
# Run all tests
zig build test

# Test with different optimization levels
zig build test -Doptimize=Debug
zig build test -Doptimize=ReleaseSafe
zig build test -Doptimize=ReleaseFast

# Run the example
zig build run

# Generate documentation
zig build docs
```

### 6. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "Add feature: brief description

Longer description of what the commit does and why.
References #issue-number if applicable."
```

**Commit Message Guidelines**:
- Use the imperative mood ("Add feature" not "Added feature")
- Keep the first line under 50 characters
- Reference issues with #number
- Explain the "why" not just the "what"

### 7. Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create a pull request on GitHub
# Include a description of your changes
```

**Pull Request Template**:
```markdown
## Description
Brief description of the changes

## Related Issue
Fixes #issue-number

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
- [ ] All existing tests pass
- [ ] Added tests for new functionality
- [ ] Tested on multiple platforms (if applicable)

## Documentation
- [ ] Updated relevant documentation
- [ ] Added code comments where needed

## Breaking Changes
List any breaking changes and migration path
```

## Types of Contributions

### Bug Fixes

**Small Fixes**:
- Typos in documentation
- Small code corrections
- Test improvements

**Process**:
1. Create issue (optional for obvious fixes)
2. Make minimal fix
3. Add test if applicable
4. Submit pull request

### New Features

**Before Starting**:
- Discuss the feature in an issue
- Get consensus on the approach
- Consider backward compatibility

**Implementation**:
- Write comprehensive tests
- Update documentation
- Consider performance implications
- Ensure thread safety

### Documentation

**Types**:
- API documentation improvements
- Tutorial updates
- Example code
- Architecture explanations

**Guidelines**:
- Use clear, concise language
- Include code examples
- Test all code examples
- Update table of contents

### Performance Improvements

**Process**:
1. Create benchmarks to measure current performance
2. Implement optimization
3. Measure improvement
4. Ensure no regressions in functionality
5. Document the improvement

**Example Benchmark**:
```zig
const BenchmarkSuite = struct {
    fn benchmarkMessageProcessing(allocator: std.mem.Allocator) !void {
        const iterations = 1000000;
        
        var engine = try ActorEngine.init(allocator);
        defer engine.deinit();
        
        try engine.spawn(BenchMessage, BenchMessage.handle);
        
        const start = std.time.nanoTimestamp();
        
        for (0..iterations) |_| {
            var msg = BenchMessage.Test;
            try engine.send(BenchMessage, &msg);
        }
        
        const end = std.time.nanoTimestamp();
        const duration = end - start;
        const ns_per_message = duration / iterations;
        
        std.debug.print("Processed {} messages in {}ns ({d:.2} ns/message)\n", 
                       .{ iterations, duration, @as(f64, @floatFromInt(ns_per_message)) });
    }
};
```

## Code Review Process

### As a Reviewer

**What to Look For**:
- Code correctness and safety
- Performance implications
- Test coverage
- Documentation quality
- Adherence to style guidelines

**Review Comments**:
- Be constructive and helpful
- Suggest specific improvements
- Explain the reasoning behind requests
- Acknowledge good practices

**Example Review Comments**:
```
// Good
"Consider using an arena allocator here for better performance 
with temporary allocations. See docs/best-practices.md for examples."

// Avoid
"This is wrong."
```

### As a Contributor

**Responding to Reviews**:
- Address all feedback
- Ask questions if unclear
- Make requested changes promptly
- Update tests and docs as needed

**Common Review Requests**:
- Add error handling
- Improve test coverage
- Update documentation
- Fix formatting issues
- Address performance concerns

## Release Process

### Version Numbering

zctor follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. **Update Version**:
   ```zig
   // In build.zig.zon
   .version = "1.2.3",
   ```

2. **Update CHANGELOG.md**:
   ```markdown
   ## [1.2.3] - 2024-01-15
   
   ### Added
   - New feature X
   
   ### Changed
   - Improved performance of Y
   
   ### Fixed
   - Bug in Z component
   ```

3. **Run Full Test Suite**:
   ```bash
   zig build test
   zig build docs
   ```

4. **Create Release Tag**:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

## Community Guidelines

### Code of Conduct

We are committed to providing a welcoming and inclusive environment:

- **Be Respectful**: Treat all contributors with respect
- **Be Constructive**: Provide helpful feedback and suggestions
- **Be Patient**: Everyone is learning and contributing at their own pace
- **Be Inclusive**: Welcome contributors regardless of experience level

### Communication

**Channels**:
- **GitHub Issues**: Bug reports, feature requests, discussions
- **Pull Requests**: Code review and collaboration
- **Discussions**: General questions and community support

**Best Practices**:
- Search existing issues before creating new ones
- Use clear, descriptive titles
- Provide sufficient context and examples
- Be patient with response times

## Getting Help

### Documentation

- Start with this documentation book
- Check the API reference
- Look at example code
- Review best practices

### Community Support

- Search existing GitHub issues
- Create a new issue with detailed information
- Join community discussions
- Ask specific, well-formed questions

### Troubleshooting

**Common Issues**:

1. **Build Failures**:
   ```bash
   # Clean and rebuild
   rm -rf zig-cache zig-out
   zig build
   ```

2. **Test Failures**:
   ```bash
   # Run specific test
   zig test src/specific_file.zig
   
   # Run with more verbose output
   zig build test --verbose
   ```

3. **Documentation Generation**:
   ```bash
   # Ensure Python 3 is available
   python3 --version
   
   # Run documentation generator
   zig build docs
   ```

## Recognition

### Contributors

We recognize all types of contributions:
- Code contributions
- Documentation improvements
- Bug reports
- Feature suggestions
- Community support

### Attribution

Contributors are recognized in:
- `CONTRIBUTORS.md` file
- Release notes
- Documentation acknowledgments

## Thank You

Thank you for contributing to zctor! Your contributions help make this project better for everyone. Every contribution, no matter how small, is valuable and appreciated.

## Next Steps

- [Examples](./06-examples.md) - See practical implementations
- [Best Practices](./07-best-practices.md) - Learn optimization techniques
- [Advanced Topics](./08-advanced-topics.md) - Explore complex patterns
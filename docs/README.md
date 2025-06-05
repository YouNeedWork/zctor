# zctor Documentation Book

Welcome to the comprehensive documentation for zctor, a lightweight, high-performance actor framework for Zig.

## 📚 Documentation Structure

This documentation book is organized into the following sections:

1. **[Introduction](./01-introduction.md)** - Overview and key concepts
2. **[Installation](./02-installation.md)** - Getting started with zctor
3. **[Quick Start](./03-quick-start.md)** - Your first actor program
4. **[Architecture](./04-architecture.md)** - Core components and design
5. **[API Reference](./05-api-reference.md)** - Complete API documentation
6. **[Examples](./06-examples.md)** - Practical examples and use cases
7. **[Best Practices](./07-best-practices.md)** - Tips and recommendations
8. **[Advanced Topics](./08-advanced-topics.md)** - Advanced usage patterns
9. **[Contributing](./09-contributing.md)** - How to contribute to zctor
10. **[Appendix](./10-appendix.md)** - Additional resources and references

## 🔧 Auto-Generation

This documentation is automatically generated from:
- Source code comments and documentation
- README.md content
- Example code in the repository
- Build system integration

### Regenerate Documentation

To regenerate the documentation, use the provided build commands:

```bash
# Generate API documentation from source code
zig build docs

# Generate complete documentation book
zig build book

# Generate all documentation
zig build docs-all
```

Or run the scripts directly:

```bash
# Generate API reference
python3 docs/generate_docs.py src docs

# Generate complete book
python3 docs/generate_book.py docs -o docs/zctor-complete-book.md

# Validate documentation
python3 docs/generate_book.py docs --validate
```

## 📖 Reading Options

### Individual Chapters
Read each chapter separately for focused learning:
- Start with [Introduction](./01-introduction.md) for overview
- Follow [Installation](./02-installation.md) and [Quick Start](./03-quick-start.md) to get started
- Deep dive into [Architecture](./04-architecture.md) for understanding
- Reference [API Documentation](./05-api-reference.md) for implementation details

### Complete Book
For offline reading or comprehensive study:
- **Markdown**: [zctor-complete-book.md](./zctor-complete-book.md)
- **HTML**: Generate with `python3 docs/generate_book.py docs --format html`

## 🧭 Navigation

- [Table of Contents](./table-of-contents.md) - Complete outline
- [Index](./index.md) - Term and concept index  
- [Glossary](./glossary.md) - Definitions and explanations

## 🛠️ Tools and Scripts

### Documentation Generation
- `generate_docs.py` - Extracts API documentation from source code
- `generate_book.py` - Combines chapters into complete book

### Features
- **Auto-extraction** of function signatures and documentation
- **Type information** from Zig source files
- **Cross-references** between documentation sections
- **Multiple output formats** (Markdown, HTML)
- **Validation** of documentation completeness

## 🚀 Quick Start

New to zctor? Start here:

1. **[Installation](./02-installation.md)** - Set up zctor in your project
2. **[Quick Start](./03-quick-start.md)** - Build your first actor in 5 minutes
3. **[Examples](./06-examples.md)** - See practical implementations
4. **[Best Practices](./07-best-practices.md)** - Learn the recommended patterns

## 🔍 Finding Information

- **Learning**: Start with Introduction → Quick Start → Examples
- **Reference**: Use API Reference and Index for specific information
- **Advanced**: Check Advanced Topics and Best Practices
- **Contributing**: See Contributing guide for development info

## 📝 Contributing to Documentation

Documentation improvements are welcome! See the [Contributing](./09-contributing.md) guide for:
- How to improve existing documentation
- Adding new examples
- Fixing typos and errors
- Translating documentation

## 📄 License

This documentation is part of the zctor project and is licensed under the MIT License. See the [Appendix](./10-appendix.md) for full license information.
#!/usr/bin/env python3
"""
Generate a complete documentation book from individual chapters.
Can output HTML, PDF, or combined markdown.
"""

import os
from pathlib import Path
import argparse
from datetime import datetime

class BookGenerator:
    def __init__(self, docs_dir: str):
        self.docs_dir = Path(docs_dir)
        self.chapters = [
            ("README.md", "Introduction to the Documentation"),
            ("01-introduction.md", "Introduction"),
            ("02-installation.md", "Installation"),
            ("03-quick-start.md", "Quick Start"),
            ("04-architecture.md", "Architecture"),
            ("05-api-reference.md", "API Reference"),
            ("06-examples.md", "Examples"),
            ("07-best-practices.md", "Best Practices"),
            ("08-advanced-topics.md", "Advanced Topics"),
            ("09-contributing.md", "Contributing"),
            ("10-appendix.md", "Appendix"),
        ]
    
    def generate_combined_markdown(self, output_file: str):
        """Generate a single markdown file with all chapters."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        with open(output_file, 'w') as f:
            # Write book header
            f.write("# zctor Documentation Book\n\n")
            f.write("A comprehensive guide to the zctor actor framework for Zig.\n\n")
            f.write(f"*Generated on {timestamp}*\n\n")
            f.write("---\n\n")
            
            # Write table of contents
            f.write("## Table of Contents\n\n")
            for i, (filename, title) in enumerate(self.chapters, 1):
                f.write(f"{i}. [{title}](#{title.lower().replace(' ', '-').replace('(', '').replace(')', '')})\n")
            f.write("\n---\n\n")
            
            # Write each chapter
            for i, (filename, title) in enumerate(self.chapters, 1):
                chapter_file = self.docs_dir / filename
                if chapter_file.exists():
                    f.write(f"# {i}. {title}\n\n")
                    
                    with open(chapter_file, 'r') as chapter:
                        content = chapter.read()
                        # Skip the first header line if it exists
                        lines = content.split('\n')
                        if lines and lines[0].startswith('#'):
                            content = '\n'.join(lines[1:])
                        f.write(content)
                    
                    f.write("\n\n---\n\n")
                else:
                    f.write(f"# {i}. {title}\n\n*Chapter not found: {filename}*\n\n---\n\n")
        
        print(f"Combined markdown book generated: {output_file}")
    
    def generate_html(self, output_file: str):
        """Generate HTML book (requires markdown processor)."""
        try:
            import markdown
        except ImportError:
            print("Error: markdown package required for HTML generation")
            print("Install with: pip install markdown")
            return
        
        # Generate combined markdown first
        temp_md = "temp_book.md"
        self.generate_combined_markdown(temp_md)
        
        # Convert to HTML
        with open(temp_md, 'r') as f:
            md_content = f.read()
        
        html_content = markdown.markdown(md_content, extensions=['toc', 'codehilite'])
        
        # Wrap in HTML document
        full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>zctor Documentation Book</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }}
        code {{ background: #f4f4f4; padding: 2px 4px; border-radius: 3px; }}
        pre {{ background: #f4f4f4; padding: 10px; border-radius: 5px; overflow-x: auto; }}
        h1, h2, h3 {{ color: #333; }}
        blockquote {{ border-left: 4px solid #ddd; margin: 0; padding-left: 20px; }}
        table {{ border-collapse: collapse; width: 100%; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
    </style>
</head>
<body>
{html_content}
</body>
</html>"""
        
        with open(output_file, 'w') as f:
            f.write(full_html)
        
        # Clean up temp file
        os.remove(temp_md)
        print(f"HTML book generated: {output_file}")
    
    def list_chapters(self):
        """List all available chapters."""
        print("Available chapters:")
        for i, (filename, title) in enumerate(self.chapters, 1):
            chapter_file = self.docs_dir / filename
            status = "✓" if chapter_file.exists() else "✗"
            print(f"  {i:2d}. {status} {title} ({filename})")
    
    def validate_chapters(self):
        """Validate that all chapters exist and are readable."""
        print("Validating chapters...")
        all_valid = True
        
        for filename, title in self.chapters:
            chapter_file = self.docs_dir / filename
            if not chapter_file.exists():
                print(f"  ✗ Missing: {title} ({filename})")
                all_valid = False
            elif not chapter_file.is_file():
                print(f"  ✗ Not a file: {title} ({filename})")
                all_valid = False
            else:
                try:
                    with open(chapter_file, 'r') as f:
                        content = f.read()
                        if len(content.strip()) == 0:
                            print(f"  ⚠ Empty: {title} ({filename})")
                        else:
                            print(f"  ✓ Valid: {title} ({filename}) - {len(content)} chars")
                except Exception as e:
                    print(f"  ✗ Error reading: {title} ({filename}) - {e}")
                    all_valid = False
        
        print(f"\nValidation {'passed' if all_valid else 'failed'}")
        return all_valid

def main():
    parser = argparse.ArgumentParser(description="Generate zctor documentation book")
    parser.add_argument("docs_dir", help="Documentation directory")
    parser.add_argument("--format", choices=["markdown", "html"], default="markdown", 
                       help="Output format")
    parser.add_argument("--output", "-o", help="Output file")
    parser.add_argument("--list", action="store_true", help="List available chapters")
    parser.add_argument("--validate", action="store_true", help="Validate chapters")
    
    args = parser.parse_args()
    
    generator = BookGenerator(args.docs_dir)
    
    if args.list:
        generator.list_chapters()
        return
    
    if args.validate:
        generator.validate_chapters()
        return
    
    # Determine output file
    if args.output:
        output_file = args.output
    else:
        if args.format == "html":
            output_file = "zctor-book.html"
        else:
            output_file = "zctor-book.md"
    
    # Generate book
    if args.format == "html":
        generator.generate_html(output_file)
    else:
        generator.generate_combined_markdown(output_file)

if __name__ == "__main__":
    main()
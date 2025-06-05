#!/usr/bin/env python3
"""
Auto-documentation generator for zctor
Extracts documentation from source files and generates markdown documentation.
"""

import os
import re
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple

class DocGenerator:
    def __init__(self, src_dir: str, docs_dir: str):
        self.src_dir = Path(src_dir)
        self.docs_dir = Path(docs_dir)
        self.api_docs = {}
        
    def extract_doc_comments(self, content: str) -> List[str]:
        """Extract //! and /// comments from Zig source."""
        doc_comments = []
        lines = content.split('\n')
        
        for line in lines:
            stripped = line.strip()
            if stripped.startswith('//!'):
                doc_comments.append(stripped[3:].strip())
            elif stripped.startswith('///'):
                doc_comments.append(stripped[3:].strip())
                
        return doc_comments
    
    def extract_function_signatures(self, content: str) -> List[Dict]:
        """Extract public function signatures and their documentation."""
        functions = []
        lines = content.split('\n')
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Look for pub fn declarations
            if stripped.startswith('pub fn '):
                func_match = re.match(r'pub fn\s+(\w+)\s*\((.*?)\)\s*(.*?)(?:\{|$)', stripped)
                if func_match:
                    name = func_match.group(1)
                    params = func_match.group(2)
                    return_type = func_match.group(3)
                    
                    # Look for preceding comments
                    doc_lines = []
                    j = i - 1
                    while j >= 0 and lines[j].strip().startswith('///'):
                        doc_lines.insert(0, lines[j].strip()[3:].strip())
                        j -= 1
                    
                    functions.append({
                        'name': name,
                        'params': params,
                        'return_type': return_type.strip(),
                        'documentation': '\n'.join(doc_lines) if doc_lines else '',
                        'line': i + 1
                    })
        
        return functions
    
    def extract_structs_and_enums(self, content: str) -> List[Dict]:
        """Extract struct and enum definitions."""
        types = []
        lines = content.split('\n')
        
        for i, line in enumerate(lines):
            stripped = line.strip()
            
            # Look for pub const declarations that define types
            if (stripped.startswith('pub const ') and 
                ('struct' in stripped or 'union' in stripped or 'enum' in stripped)):
                
                type_match = re.match(r'pub const\s+(\w+)\s*=\s*(.*?)(?:\{|$)', stripped)
                if type_match:
                    name = type_match.group(1)
                    type_def = type_match.group(2)
                    
                    # Look for preceding comments
                    doc_lines = []
                    j = i - 1
                    while j >= 0 and lines[j].strip().startswith('///'):
                        doc_lines.insert(0, lines[j].strip()[3:].strip())
                        j -= 1
                    
                    types.append({
                        'name': name,
                        'type': type_def.strip(),
                        'documentation': '\n'.join(doc_lines) if doc_lines else '',
                        'line': i + 1
                    })
        
        return types
    
    def process_source_file(self, file_path: Path) -> Dict:
        """Process a single source file and extract documentation."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            print(f"Warning: Could not read {file_path} as UTF-8")
            return {}
        
        relative_path = file_path.relative_to(self.src_dir)
        
        return {
            'file': str(relative_path),
            'module_docs': self.extract_doc_comments(content),
            'functions': self.extract_function_signatures(content),
            'types': self.extract_structs_and_enums(content)
        }
    
    def generate_api_reference(self) -> str:
        """Generate the API reference markdown."""
        markdown = """# API Reference

This is the complete API reference for zctor, automatically generated from source code.

"""
        
        for file_info in self.api_docs.values():
            if not any([file_info['module_docs'], file_info['functions'], file_info['types']]):
                continue
                
            markdown += f"## {file_info['file']}\n\n"
            
            # Module documentation
            if file_info['module_docs']:
                markdown += "### Module Documentation\n\n"
                for doc in file_info['module_docs']:
                    if doc:
                        markdown += f"{doc}\n\n"
            
            # Types
            if file_info['types']:
                markdown += "### Types\n\n"
                for type_info in file_info['types']:
                    markdown += f"#### `{type_info['name']}`\n\n"
                    if type_info['documentation']:
                        markdown += f"{type_info['documentation']}\n\n"
                    markdown += f"```zig\n{type_info['type']}\n```\n\n"
            
            # Functions
            if file_info['functions']:
                markdown += "### Functions\n\n"
                for func in file_info['functions']:
                    markdown += f"#### `{func['name']}`\n\n"
                    if func['documentation']:
                        markdown += f"{func['documentation']}\n\n"
                    
                    signature = f"pub fn {func['name']}({func['params']})"
                    if func['return_type']:
                        signature += f" {func['return_type']}"
                    
                    markdown += f"```zig\n{signature}\n```\n\n"
            
            markdown += "---\n\n"
        
        return markdown
    
    def scan_source_files(self):
        """Scan all Zig source files and extract documentation."""
        for zig_file in self.src_dir.glob('**/*.zig'):
            if zig_file.is_file():
                file_info = self.process_source_file(zig_file)
                if file_info:
                    self.api_docs[str(zig_file)] = file_info
    
    def generate_table_of_contents(self) -> str:
        """Generate table of contents for the documentation."""
        toc = """# Table of Contents

## zctor Documentation Book

1. **[Introduction](./01-introduction.md)**
   - What is the Actor Model?
   - Why zctor?
   - Key Features
   - Use Cases
   - Architecture Overview

2. **[Installation](./02-installation.md)**
   - Requirements
   - Installation Methods
   - Verifying Installation
   - Development Setup
   - Troubleshooting

3. **[Quick Start](./03-quick-start.md)**
   - Your First Actor
   - Adding State
   - Multiple Actors
   - Common Patterns

4. **[Architecture](./04-architecture.md)**
   - Core Components
   - Message Flow
   - Threading Model
   - Memory Management

5. **[API Reference](./05-api-reference.md)**
   - ActorEngine
   - Actor(T)
   - ActorThread
   - Context
   - Generated API Documentation

6. **[Examples](./06-examples.md)**
   - Basic Examples
   - Real-world Use Cases
   - Performance Examples
   - Integration Examples

7. **[Best Practices](./07-best-practices.md)**
   - Design Patterns
   - Performance Tips
   - Error Handling
   - Testing Strategies

8. **[Advanced Topics](./08-advanced-topics.md)**
   - Custom Allocators
   - Supervisors
   - Distributed Actors
   - Performance Tuning

9. **[Contributing](./09-contributing.md)**
   - Development Environment
   - Code Style
   - Testing
   - Documentation

10. **[Appendix](./10-appendix.md)**
    - Glossary
    - References
    - License Information

## Navigation

- [Home](./README.md)
- [Index](./index.md)
- [Glossary](./glossary.md)
"""
        return toc
    
    def generate_docs(self):
        """Generate all documentation."""
        print("Scanning source files...")
        self.scan_source_files()
        
        print(f"Found {len(self.api_docs)} source files with documentation")
        
        # Generate API reference
        print("Generating API reference...")
        api_ref = self.generate_api_reference()
        api_ref_path = self.docs_dir / "05-api-reference.md"
        with open(api_ref_path, 'w') as f:
            f.write(api_ref)
        
        # Generate table of contents
        print("Generating table of contents...")
        toc = self.generate_table_of_contents()
        toc_path = self.docs_dir / "table-of-contents.md"
        with open(toc_path, 'w') as f:
            f.write(toc)
        
        print(f"Documentation generated in {self.docs_dir}")
        print(f"- API Reference: {api_ref_path}")
        print(f"- Table of Contents: {toc_path}")

def main():
    """Main entry point."""
    import sys
    
    if len(sys.argv) != 3:
        print("Usage: python3 generate_docs.py <src_dir> <docs_dir>")
        sys.exit(1)
    
    src_dir = sys.argv[1]
    docs_dir = sys.argv[2]
    
    generator = DocGenerator(src_dir, docs_dir)
    generator.generate_docs()

if __name__ == "__main__":
    main()
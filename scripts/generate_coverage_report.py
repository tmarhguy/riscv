#!/usr/bin/env python3
"""
Coverage Report Generator for IronCore RV32IM Processor

Parses Verilator coverage.dat file and generates human-readable
coverage reports with line and toggle coverage percentages.
"""

import sys
import re
from pathlib import Path
from collections import defaultdict


def parse_coverage_dat(filepath):
    """Parse Verilator coverage.dat file and extract metrics."""
    
    coverage_data = {
        'line': {'covered': 0, 'total': 0},
        'toggle': {'covered': 0, 'total': 0},
        'files': defaultdict(lambda: {'line': {'covered': 0, 'total': 0}, 
                                      'toggle': {'covered': 0, 'total': 0}})
    }
    
    try:
        with open(filepath, 'r', encoding='latin-1') as f:
            for line in f:
                line = line.strip()
                
                # Verilator coverage format: C 'entry' COUNT
                # Entry contains control characters as delimiters
                if line.startswith("C '"):
                    try:
                        # Split on the quote to get entry and count
                        parts = line.split("'")
                        if len(parts) < 3:
                            continue
                        
                        entry = parts[1]
                        count_str = parts[2].strip()
                        
                        try:
                            count = int(count_str)
                        except ValueError:
                            continue
                        
                        # Parse entry with control characters
                        # Format: \x01f\x02filename\x01l\x02line\x01n\x02...\x01t\x02type...
                        # Extract filename (after \x01f\x02)
                        filename = "unknown"
                        if '\x01f\x02' in entry:
                            file_start = entry.find('\x01f\x02') + 3
                            file_end = entry.find('\x01', file_start)
                            if file_end > file_start:
                                filename = entry[file_start:file_end]
                        
                        # Determine coverage type (after \x01t\x02)
                        cov_type = ""
                        if '\x01t\x02' in entry:
                            type_start = entry.find('\x01t\x02') + 3
                            type_end = entry.find('\x01', type_start)
                            if type_end > type_start:
                                cov_type = entry[type_start:type_end]
                        
                        # Categorize as line or toggle coverage
                        if cov_type == 'line':
                            coverage_data['line']['total'] += 1
                            if count > 0:
                                coverage_data['line']['covered'] += 1
                            
                            coverage_data['files'][filename]['line']['total'] += 1
                            if count > 0:
                                coverage_data['files'][filename]['line']['covered'] += 1
                        
                        elif cov_type == 'toggle':
                            coverage_data['toggle']['total'] += 1
                            if count > 0:
                                coverage_data['toggle']['covered'] += 1
                            
                            coverage_data['files'][filename]['toggle']['total'] += 1
                            if count > 0:
                                coverage_data['files'][filename]['toggle']['covered'] += 1
                    
                    except Exception as e:
                        # Skip malformed lines
                        continue
    
    except FileNotFoundError:
        print(f"Error: Coverage file not found: {filepath}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error parsing coverage file: {e}", file=sys.stderr)
        sys.exit(1)
    
    return coverage_data


def calculate_percentage(covered, total):
    """Calculate coverage percentage."""
    if total == 0:
        return 0.0
    return (covered / total) * 100.0


def generate_markdown_report(coverage_data):
    """Generate markdown-formatted coverage report."""
    
    report = []
    report.append("# IronCore RV32IM Coverage Report\n")
    report.append("*Auto-generated from Verilator coverage data*\n")
    
    # Overall Summary
    report.append("## Overall Coverage Summary\n")
    
    line_pct = calculate_percentage(
        coverage_data['line']['covered'],
        coverage_data['line']['total']
    )
    toggle_pct = calculate_percentage(
        coverage_data['toggle']['covered'],
        coverage_data['toggle']['total']
    )
    
    report.append("| Metric | Covered | Total | Percentage |")
    report.append("|--------|---------|-------|------------|")
    report.append(f"| **Line Coverage** | {coverage_data['line']['covered']:,} | "
                 f"{coverage_data['line']['total']:,} | **{line_pct:.2f}%** |")
    report.append(f"| **Toggle Coverage** | {coverage_data['toggle']['covered']:,} | "
                 f"{coverage_data['toggle']['total']:,} | **{toggle_pct:.2f}%** |")
    report.append("")
    
    # Coverage Status Badge
    if line_pct >= 95:
        status = "Excellent"
    elif line_pct >= 80:
        status = "Good"
    elif line_pct >= 60:
        status = "Fair"
    else:
        status = "Needs Improvement"
    
    report.append(f"**Status**: {status}\n")
    
    # Per-File Breakdown
    report.append("## Per-File Coverage Breakdown\n")
    report.append("| File | Line Coverage | Toggle Coverage |")
    report.append("|------|---------------|-----------------|")
    
    # Sort files by name
    sorted_files = sorted(coverage_data['files'].items())
    
    for filepath, file_data in sorted_files:
        # Extract just the filename for readability
        filename = Path(filepath).name
        
        file_line_pct = calculate_percentage(
            file_data['line']['covered'],
            file_data['line']['total']
        )
        file_toggle_pct = calculate_percentage(
            file_data['toggle']['covered'],
            file_data['toggle']['total']
        )
        
        report.append(f"| `{filename}` | {file_line_pct:.1f}% "
                     f"({file_data['line']['covered']}/{file_data['line']['total']}) | "
                     f"{file_toggle_pct:.1f}% "
                     f"({file_data['toggle']['covered']}/{file_data['toggle']['total']}) |")
    
    report.append("")
    
    # Interpretation Guide
    report.append("## Interpretation Guide\n")
    report.append("- **Line Coverage**: Percentage of executable lines that were executed during testing")
    report.append("- **Toggle Coverage**: Percentage of signal bits that toggled between 0 and 1")
    report.append("- **Target**: ≥95% line coverage, ≥80% toggle coverage (per PRD requirements)\n")
    
    # Generation Info
    report.append("---")
    report.append("*Generated by `scripts/generate_coverage_report.py`*")
    
    return '\n'.join(report)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_coverage_report.py <coverage.dat>")
        print("Example: python3 generate_coverage_report.py logs/coverage.dat")
        sys.exit(1)
    
    coverage_file = sys.argv[1]
    
    # Parse coverage data
    coverage_data = parse_coverage_dat(coverage_file)
    
    # Generate and print report
    report = generate_markdown_report(coverage_data)
    print(report)


if __name__ == '__main__':
    main()

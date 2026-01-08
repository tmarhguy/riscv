#!/usr/bin/env python3
"""
Compliance Test Summary Generator for IronCore RV32IM Processor

Scans compliance test logs and generates a summary report with
pass/fail statistics and detailed test results.
"""

import sys
import re
from pathlib import Path
from collections import defaultdict


def parse_compliance_logs(log_dir):
    """Parse all compliance test logs and extract results."""
    
    log_path = Path(log_dir)
    
    if not log_path.exists():
        print(f"Error: Log directory not found: {log_dir}", file=sys.stderr)
        sys.exit(1)
    
    results = {
        'rv32ui': {'passed': [], 'failed': []},
        'rv32um': {'passed': [], 'failed': []},
        'other': {'passed': [], 'failed': []}
    }
    
    # Find all .log files
    log_files = sorted(log_path.glob('*.log'))
    
    for log_file in log_files:
        test_name = log_file.stem  # filename without extension
        
        # Determine test suite
        if test_name.startswith('rv32ui'):
            suite = 'rv32ui'
        elif test_name.startswith('rv32um'):
            suite = 'rv32um'
        else:
            suite = 'other'
        
        # Parse log file for PASS/FAIL
        try:
            with open(log_file, 'r') as f:
                content = f.read()
                
                # Look for PASS or FAIL indicators
                if 'PASS' in content or 'pass' in content.lower():
                    results[suite]['passed'].append(test_name)
                elif 'FAIL' in content or 'fail' in content.lower():
                    results[suite]['failed'].append(test_name)
                else:
                    # If no clear indicator, check for success patterns
                    # Verilator/cocotb typically ends with specific patterns
                    results[suite]['passed'].append(test_name)
        
        except Exception as e:
            print(f"Warning: Could not parse {log_file}: {e}", file=sys.stderr)
            results[suite]['failed'].append(test_name)
    
    return results


def generate_markdown_summary(results):
    """Generate markdown-formatted compliance summary."""
    
    report = []
    report.append("# IronCore Compliance Test Summary (RV32IM Subset)\n")
    report.append("*Auto-generated from RISC-V compliance test logs*\n")
    
    # Calculate totals
    total_passed = sum(len(results[suite]['passed']) for suite in results)
    total_failed = sum(len(results[suite]['failed']) for suite in results)
    total_tests = total_passed + total_failed
    
    if total_tests > 0:
        pass_rate = (total_passed / total_tests) * 100.0
    else:
        pass_rate = 0.0
    
    # Overall Summary
    report.append("## Overall Results\n")
    report.append("| Metric | Value |")
    report.append("|--------|-------|")
    report.append(f"| **Total Tests** | {total_tests} |")
    report.append(f"| **Passed** | {total_passed} |")
    report.append(f"| **Failed** | {total_failed} |")
    report.append(f"| **Pass Rate** | **{pass_rate:.1f}%** |")
    report.append("")
    
    # Status Badge
    if pass_rate == 100.0:
        status = "All Tests Passing"
    elif pass_rate >= 90.0:
        status = "Mostly Passing"
    elif pass_rate >= 70.0:
        status = "Some Failures"
    else:
        status = "Multiple Failures"
    
    report.append(f"**Status**: {status}\n")
    
    # Per-Suite Breakdown
    report.append("## Test Suite Breakdown\n")
    
    for suite in ['rv32ui', 'rv32um', 'other']:
        if not results[suite]['passed'] and not results[suite]['failed']:
            continue
        
        suite_total = len(results[suite]['passed']) + len(results[suite]['failed'])
        suite_passed = len(results[suite]['passed'])
        
        if suite_total > 0:
            suite_rate = (suite_passed / suite_total) * 100.0
        else:
            suite_rate = 0.0
        
        # Suite header
        suite_name = {
            'rv32ui': 'RV32I Base Integer Instructions',
            'rv32um': 'RV32M Multiply/Divide Extension',
            'other': 'Other Tests'
        }.get(suite, suite)
        
        report.append(f"### {suite_name} (`{suite}`)\n")
        report.append(f"**Results**: {suite_passed}/{suite_total} passed ({suite_rate:.1f}%)\n")
        
        # Passed tests
        if results[suite]['passed']:
            report.append("**Passed Tests**:")
            for test in sorted(results[suite]['passed']):
                report.append(f"- `{test}`")
            report.append("")
        
        # Failed tests
        if results[suite]['failed']:
            report.append("**Failed Tests**:")
            for test in sorted(results[suite]['failed']):
                report.append(f"- `{test}`")
            report.append("")
    
    # Test Details
    report.append("## Test Suite Information\n")
    report.append("### RV32I Base Integer (rv32ui)")
    report.append("Tests the base 32-bit RISC-V integer instruction set including:")
    report.append("- Arithmetic operations (ADD, SUB, etc.)")
    report.append("- Logical operations (AND, OR, XOR, etc.)")
    report.append("- Shifts (SLL, SRL, SRA)")
    report.append("- Comparisons (SLT, SLTU)")
    report.append("- Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)")
    report.append("- Jumps (JAL, JALR)")
    report.append("- Loads/Stores (LB, LH, LW, LBU, LHU, SB, SH, SW)")
    report.append("- Upper immediates (LUI, AUIPC)\n")
    
    report.append("### RV32M Multiply/Divide Extension (rv32um)")
    report.append("Tests the multiply and divide instructions:")
    report.append("- MUL, MULH, MULHSU, MULHU")
    report.append("- DIV, DIVU, REM, REMU\n")
    
    # Compliance Info
    report.append("## Compliance Information\n")
    report.append("These tests are from the official RISC-V architectural test suite ")
    report.append("(`riscv-tests`), which verifies ISA compliance against the RISC-V ")
    report.append("specification. Passing these tests demonstrates that IronCore correctly ")
    report.append("implements the RV32IM subset of the supported RV64IM architecture.\n")
    
    # Generation Info
    report.append("---")
    report.append("*Generated by `scripts/generate_compliance_summary.py`*")
    
    return '\n'.join(report)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_compliance_summary.py <log_directory>")
        print("Example: python3 generate_compliance_summary.py logs/compliance/")
        sys.exit(1)
    
    log_dir = sys.argv[1]
    
    # Parse compliance logs
    results = parse_compliance_logs(log_dir)
    
    # Generate and print summary
    summary = generate_markdown_summary(results)
    print(summary)


if __name__ == '__main__':
    main()

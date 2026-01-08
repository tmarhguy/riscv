# Scripts Directory

This directory contains utility scripts for building, testing, and synthesizing the IronCore processor.

## Key Scripts

| Script | description |
|--------|-------------|
| `run_tests.sh` | Main test runner wrapper used by `make regress`. Handles test discovery and execution. |
| `run_compliance.sh` | Wrapper for running RISC-V compliance tests. |
| `synth/` | Folder containing Yosys synthesis scripts and checkpoints. |

# Software Directory (sw)

This directory contains bare-metal software tests and runtime support for the IronCore processor.

## Purpose
To provide C and Assembly test cases that verify the processor's ability to execute compiled code and interact with peripherals.

## Contents

*   `hello.c`: Basic functionality demonstration (IO access).
*   `linker.ld`: Linker script defining memory map (RAM/ROM locations).
*   `start.S`: Boot code / crt0 (sets up stack, jumps to main).
*   `Makefile`: Rules to compile `.c`/`.S` files into `.hex` or `.bin` for simulation.

## Building Software

You need `riscv32-unknown-elf-gcc` installed (or use the Docker container).

To build the software artifacts:
```bash
# Usually called automatically by `make cocotb` or `make regress`
make -C sw
```

## Memory Map

*   **ROM / Instr**: `0x0000_0000`
*   **RAM / Data**: `0x8000_0000`
*   **IO / UART**: `0x1000_0000`

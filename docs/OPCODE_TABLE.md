# IronCore Opcode Map

This document lists the RISC-V instructions supported by the **IronCore RV64IM** processor.

## RV64I Base Integer Set

### Integer Computation (Register-Immediate)
| Instruction | Format | Opcode | Funct3 | Funct7 | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `ADDI` | I | `0010011` | `000` | - | Add Immediate |
| `SLTI` | I | `0010011` | `010` | - | Set Less Than Immediate |
| `SLTIU` | I | `0010011` | `011` | - | Set Less Than Immediate Unsigned |
| `XORI` | I | `0010011` | `100` | - | XOR Immediate |
| `ORI` | I | `0010011` | `110` | - | OR Immediate |
| `ANDI` | I | `0010011` | `111` | - | AND Immediate |
| `SLLI` | I | `0010011` | `001` | `0000000` | Shift Left Logical Immediate |
| `SRLI` | I | `0010011` | `101` | `0000000` | Shift Right Logical Immediate |
| `SRAI` | I | `0010011` | `101` | `0100000` | Shift Right Arithmetic Immediate |
| `LUI` | U | `0110111` | - | - | Load Upper Immediate |
| `AUIPC` | U | `0010111` | - | - | Add Upper Immediate to PC |

### Integer Computation (Register-Register)
| Instruction | Format | Opcode | Funct3 | Funct7 | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `ADD` | R | `0110011` | `000` | `0000000` | Add |
| `SUB` | R | `0110011` | `000` | `0100000` | Subtract |
| `SLL` | R | `0110011` | `001` | `0000000` | Shift Left Logical |
| `SLT` | R | `0110011` | `010` | `0000000` | Set Less Than |
| `SLTU` | R | `0110011` | `011` | `0000000` | Set Less Than Unsigned |
| `XOR` | R | `0110011` | `100` | `0000000` | XOR |
| `SRL` | R | `0110011` | `101` | `0000000` | Shift Right Logical |
| `SRA` | R | `0110011` | `101` | `0100000` | Shift Right Arithmetic |
| `OR` | R | `0110011` | `110` | `0000000` | OR |
| `AND` | R | `0110011` | `111` | `0000000` | AND |

### Control Transfer
| Instruction | Format | Opcode | Funct3 | Description |
| :--- | :--- | :--- | :--- | :--- |
| `JAL` | J | `1101111` | - | Jump and Link |
| `JALR` | I | `1100111` | `000` | Jump and Link Register |
| `BEQ` | B | `1100011` | `000` | Branch Equal |
| `BNE` | B | `1100011` | `001` | Branch Not Equal |
| `BLT` | B | `1100011` | `100` | Branch Less Than |
| `BGE` | B | `1100011` | `101` | Branch Greater/Equal |
| `BLTU` | B | `1100011` | `110` | Branch Less Than Unsigned |
| `BGEU` | B | `1100011` | `111` | Branch Greater/Equal Unsigned |

### Load/Store
| Instruction | Format | Opcode | Funct3 | Description |
| :--- | :--- | :--- | :--- | :--- |
| `LB` | I | `0000011` | `000` | Load Byte |
| `LH` | I | `0000011` | `001` | Load Halfword |
| `LW` | I | `0000011` | `010` | Load Word |
| `LD` | I | `0000011` | `011` | Load Doubleword |
| `LBU` | I | `0000011` | `100` | Load Byte Unsigned |
| `LHU` | I | `0000011` | `101` | Load Halfword Unsigned |
| `LWU` | I | `0000011` | `110` | Load Word Unsigned |
| `SB` | S | `0100011` | `000` | Store Byte |
| `SH` | S | `0100011` | `001` | Store Halfword |
| `SW` | S | `0100011` | `010` | Store Word |
| `SD` | S | `0100011` | `011` | Store Doubleword |

### RV64I 32-bit Operations (Word)
| Instruction | Format | Opcode | Funct3 | Funct7 | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `ADDIW` | I | `0011011` | `000` | - | Add Immediate Word |
| `SLLIW` | I | `0011011` | `001` | `0000000` | Shift Left Logical Immediate Word |
| `SRLIW` | I | `0011011` | `101` | `0000000` | Shift Right Logical Immediate Word |
| `SRAIW` | I | `0011011` | `101` | `0100000` | Shift Right Arithmetic Immediate Word |
| `ADDW` | R | `0111011` | `000` | `0000000` | Add Word |
| `SUBW` | R | `0111011` | `000` | `0100000` | Subtract Word |
| `SLLW` | R | `0111011` | `001` | `0000000` | Shift Left Logical Word |
| `SRLW` | R | `0111011` | `101` | `0000000` | Shift Right Logical Word |
| `SRAW` | R | `0111011` | `101` | `0100000` | Shift Right Arithmetic Word |

---

## RV64M Multiply/Divide Extension

Located under Opcode `0110011` (OP) and `0111011` (OP-32) with `funct7=0000001`.

### 64-bit Multiply/Divide
| Instruction | Funct3 | Description |
| :--- | :--- | :--- |
| `MUL` | `000` | Multiply check (low 64 bits) |
| `MULH` | `001` | Multiply High Signed Signed |
| `MULHSU` | `010` | Multiply High Signed Unsigned |
| `MULHU` | `011` | Multiply High Unsigned Unsigned |
| `DIV` | `100` | Divide Signed |
| `DIVU` | `101` | Divide Unsigned |
| `REM` | `110` | Remainder Signed |
| `REMU` | `111` | Remainder Unsigned |

### 32-bit Multiply/Divide (Word)
| Instruction | Funct3 | Description |
| :--- | :--- | :--- |
| `MULW` | `000` | Multiply Word |
| `DIVW` | `100` | Divide Word Signed |
| `DIVUW` | `101` | Divide Word Unsigned |
| `REMW` | `110` | Remainder Word Signed |
| `REMUW` | `111` | Remainder Word Unsigned |

---

## System Instructions
Opcode: `1110011` (SYSTEM)

| Instruction | Funct3 | Funct12 | Description |
| :--- | :--- | :--- | :--- |
| `ECALL` | `000` | `000000000000` | Environment Call |
| `EBREAK` | `000` | `000000000001` | Breakpoint |
| `MRET` | `000` | `001100000010` | Machine Return |
| `CSRRW` | `001` | - | Atomic Read/Write CSR |
| `CSRRS` | `010` | - | Atomic Read and Set CSR |
| `CSRRC` | `011` | - | Atomic Read and Clear CSR |
| `CSRRWI` | `101` | - | Atomic Read/Write CSR Immediate |
| `CSRRSI` | `110` | - | Atomic Read and Set CSR Immediate |
| `CSRRCI` | `111` | - | Atomic Read and Clear CSR Immediate |

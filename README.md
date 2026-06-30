# Design and Simulation of a 4-bit Processor

**Language:** Verilog (synthesizable, Verilog-2001 style)
**Simulator used here:** Icarus Verilog (`iverilog`/`vvp`) — instructions for ModelSim/Vivado included below
**Architecture:** Single-cycle, non-pipelined, Harvard-style (separate instruction ROM and data RAM)

---

## 1. Architecture Overview

```
                 ┌──────────────┐
   PC ──────────►│ Instruction  │── instr[7:0] ──► Control Unit (decode)
   (4-bit)        │  Memory(ROM) │                      │
                 └──────────────┘                      ▼
                                          ┌─────────────────────────┐
                                          │   Register File (4x4b)  │
                                          │   R0 R1 R2 R3            │
                                          └──────────┬───────┬──────┘
                                                     Rd      Rs
                                                      │       │
                                                      ▼       ▼
                                               ┌────────────────┐
                                               │   ALU (4-bit)   │── zero flag ──► Z register
                                               └────────┬────────┘
                                                        │
                                               ┌────────▼────────┐
                                               │ Data Memory(RAM)│  (LOAD/STORE, implicit R0)
                                               └─────────────────┘
```

## 2. Modules

| File                       | Purpose                                                         |
|------------------------------|--------------------------------------------------------------------|
| `alu_4bit.v`                | 4-bit ALU: ADD, SUB, AND, OR, XOR, NOT, MOV; outputs result + zero flag |
| `register_file_4bit.v`     | 4 × 4-bit register file, 2 read ports + 1 synchronous write port    |
| `data_memory_4bit.v`        | 16 × 4-bit data RAM, synchronous write / combinational read         |
| `cpu_4bit_top.v`            | Top-level: instruction ROM, PC, control unit (decode + control signals), datapath wiring |
| `tb_cpu_4bit.v`             | Testbench — runs the demo program with a full per-cycle execution trace |
| `ISA.md`                    | Full instruction set reference and demo-program walkthrough         |

Full ISA, opcode table, and instruction encoding are documented in **`ISA.md`** — refer to it alongside this report.

## 3. Control Unit Design

The control unit is purely **combinational**, decoding `opcode = instr[7:4]` into:
- `is_rtype` (ADD/SUB/AND/OR/XOR/NOT/MOV) → drives ALU, register write-back
- `is_ldi / is_load / is_store` → memory & immediate transfers (implicit R0)
- `is_jz / is_jmp` → next-PC branch logic
- `is_halt` → freezes the PC permanently once latched

PC update, register write-back, memory write, and the Z-flag are all **registered** (synchronous), making this a clean single-cycle machine: one instruction fully fetches, decodes, and executes every clock edge.

## 4. Simulation Results

The testbench loads the demo program (documented in `ISA.md`): it computes **3 × 2 = 6** using a repeated-addition loop, exercising every instruction class — immediate load, register move, ALU add/sub, conditional/unconditional branch, memory store, and halt.

Captured trace (`sim_log.txt`):

```
PC | INSTR    MNEMONIC | R0 R1 R2 R3 | Z | HALT
---+--------------------+-------------+---+-----
 1 | 01110100  MOV     |  3  0  0  0 |  0 |  0
 2 | 10000010  LDI     |  3  3  0  0 |  0 |  0
 3 | 01111000  MOV     |  2  3  0  0 |  0 |  0
 4 | 10000001  LDI     |  2  3  2  0 |  0 |  0
 5 | 01111100  MOV     |  1  3  2  0 |  0 |  0
 6 | 10000000  LDI     |  1  3  2  1 |  0 |  0
 7 | 00010001  ADD     |  0  3  2  1 |  0 |  0
 8 | 00101011  SUB     |  3  3  2  1 |  0 |  0
 9 | 10111011  JZ      |  3  3  1  1 |  0 |  0    <- Z=0, branch not taken
10 | 11000111  JMP     |  3  3  1  1 |  0 |  0    <- jump back to LOOP
 7 | 00010001  ADD     |  3  3  1  1 |  0 |  0    <- R0 = 3+3 = 6
 8 | 00101011  SUB     |  6  3  1  1 |  0 |  0    <- R2 = 1-1 = 0
 9 | 10111011  JZ      |  6  3  0  1 |  1 |  0    <- Z=1, branch TAKEN
11 | 10100000  STORE   |  6  3  0  1 |  1 |  0    <- MEM[0] = 6
12 | 11110000  HALT    |  6  3  0  1 |  1 |  0
13 | 00000000  NOP     |  6  3  0  1 |  1 |  1    <- CPU halted, PC frozen

CPU halted. Final R0=6  MEM[0]=6
```

✅ **Result verified:** `R0 = 6`, `MEM[0] = 6`, exactly matching the expected 3 × 2 = 6 — confirming correct ALU arithmetic, register file read/write timing, conditional branching on the Z flag, and memory store, all working together.

## 5. Running the Simulation

### Icarus Verilog (used for the results above)
```bash
iverilog -g2012 -o sim.out alu_4bit.v register_file_4bit.v data_memory_4bit.v cpu_4bit_top.v tb_cpu_4bit.v
vvp sim.out
gtkwave cpu_4bit.vcd     # graphical waveform view
```

### ModelSim
```tcl
vlib work
vlog alu_4bit.v register_file_4bit.v data_memory_4bit.v cpu_4bit_top.v tb_cpu_4bit.v
vsim tb_cpu_4bit
add wave -r /*
run -all
```

### Vivado
1. New RTL project → add the four design files as design sources, `tb_cpu_4bit.v` as the simulation source.
2. Run Behavioral Simulation — reproduces the waveform/trace above in the Vivado simulator.
3. (Optional) Synthesize for a target Spartan-6/Artix-7 part if hardware deployment is required — add basic I/O constraints for `pc_out`/register debug outputs onto board LEDs/7-segment displays.

## 6. Possible Extensions
- Add `LOAD`/`STORE` with explicit Rd (currently implicit R0) by widening the instruction word.
- Add a carry flag and signed arithmetic.
- Pipeline the fetch/decode/execute stages.
- Add an interrupt/I/O port for a more complete microcontroller-style design.

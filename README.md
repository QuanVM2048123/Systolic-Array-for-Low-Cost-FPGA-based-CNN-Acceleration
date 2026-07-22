# Systolic Array for Low-Cost FPGA-based CNN Acceleration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Language](https://img.shields.io/badge/HDL-Verilog-blue.svg)
![Target](https://img.shields.io/badge/Target-Low--Cost%20FPGA-orange.svg)

A lightweight, parameterizable **output-stationary systolic array** implemented in Verilog, designed to accelerate the matrix-multiplication core of CNN inference (e.g. im2col-based convolution / GEMM) on low-cost FPGA boards.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Module Description](#module-description)
- [Parameters](#parameters)
- [Interface](#interface)
- [FSM (Top-Level Control)](#fsm-top-level-control)
- [Timing](#timing)
- [Repository Structure](#repository-structure)
- [Simulation](#simulation)
- [Results](#results)
- [References](#references)
- [License](#license)

## Overview

[#overview](#overview)

Convolutional Neural Network (CNN) inference is dominated by matrix-multiplication workloads. A **systolic array** maps this computation onto a regular grid of simple Processing Elements (PEs) that pass data locally between neighbors, which keeps routing short and makes the design scale well on resource-constrained, low-cost FPGAs.

This project implements a **ROWS × COLS output-stationary systolic array** that computes:

```
C (ROWS x COLS) = A (ROWS x K) x B (K x COLS)
```

Each PE accumulates one output element of `C` locally and never moves it out of the array until the computation is complete, minimizing accumulator traffic and making the design well suited to fixed-point CNN accelerators.

## Architecture

[#architecture](#architecture)

### Output-Stationary Dataflow

- Matrix **A** streams into the array from the **left**, one skewed diagonal per cycle.
- Matrix **B** streams into the array from the **top**, one skewed diagonal per cycle.
- Each PE computes `acc += a_in * b_in`, then forwards `a_in` to the PE on its right and `b_in` to the PE below it.
- The partial sum `acc` (the output element `C[r][c]`) **stays stationary** inside PE `(r, c)` for the entire computation.

```
            B[0][0]  B[0][1]  B[0][2]  B[0][3]
               |        |        |        |
A[0][*] --> PE(0,0)--PE(0,1)--PE(0,2)--PE(0,3)
               |        |        |        |
A[1][*] --> PE(1,0)--PE(1,1)--PE(1,2)--PE(1,3)
               |        |        |        |
A[2][*] --> PE(2,0)--PE(2,1)--PE(2,2)--PE(2,3)
               |        |        |        |
A[3][*] --> PE(3,0)--PE(3,1)--PE(3,2)--PE(3,3)
```

### Skewing

Because every PE needs its two operands to arrive on the same cycle *after* traveling different distances through the grid, the inputs must be **diagonally skewed** before entering the array. The `skew` module reshapes the flattened `A` and `B` matrices into per-row/per-column staggered streams (with `valid_a` / `valid_b` strobes), so row `r` of `A` and column `c` of `B` are released `r` and `c` cycles later, respectively.

## Module Description

[#module-description](#module-description)

| Module                 | File                    | Description                                                                                     |
| ----------------------- | ------------------------ | ------------------------------------------------------------------------------------------------- |
| `pe`                   | `rtl/pe.v`               | Single Processing Element: signed multiply-accumulate, registers `a`/`b` pass-through and `valid` pipeline, synchronous `clear`. |
| `skew`                 | `rtl/skew.v`             | Diagonally skews matrices `A` and `B` into per-row / per-column streams with `valid` strobes and a `done` flag. |
| `systolic_array`       | `rtl/systolic_array.v`   | Instantiates `skew` + a `ROWS x COLS` generate-block grid of `pe`, wires neighbor connections, packs the result into `C_flat`, and drives the compute-cycle counter / `done`. |
| `systolic_array_top`   | `rtl/systolic_array_top.v` | Top-level wrapper with a simple AXI-Stream-like handshake (`in_valid/in_ready`, `out_valid/out_ready`). A 5-state FSM streams matrix `A` and `B` in element-by-element, triggers the `systolic_array`, then streams matrix `C` out element-by-element. |

## Parameters

[#parameters](#parameters)

| Parameter | Default | Description                                              |
| --------- | ------- | ---------------------------------------------------------- |
| `ROWS`    | 4       | Number of rows in `A` / rows of PEs                       |
| `COLS`    | 4       | Number of columns in `B` / columns of PEs                 |
| `K`       | 4       | Shared (inner) dimension of `A` and `B`                   |
| `DW`      | 8       | Bit width of each element of `A` and `B` (signed)          |
| `ACC_DW`  | `2*DW + clog2(K)` | Accumulator / output bit width (signed), e.g. 18 bits for the defaults above |

All parameters are set at the top level (`systolic_array_top`) and propagate down to `systolic_array`, `skew`, and every `pe` instance via Verilog `parameter` overrides.

## Interface

[#interface](#interface)

`systolic_array_top` exposes a simple streaming (valid/ready) interface:

| Signal      | Direction | Width                  | Description                                            |
| ----------- | --------- | ----------------------- | -------------------------------------------------------- |
| `clk`       | in        | 1                        | Clock                                                    |
| `rst_n`     | in        | 1                        | Active-low asynchronous reset                            |
| `start`     | in        | 1                        | Pulse to begin a new `A x B` computation                |
| `in_valid`  | in        | 1                        | Input element valid                                      |
| `in_data`   | in        | `DW`                     | One signed element of `A` (then `B`), sent sequentially |
| `in_ready`  | out       | 1                        | Asserted while the module is accepting `A`/`B` elements |
| `out_ready` | in        | 1                        | Downstream ready to accept a `C` element                |
| `out_valid` | out       | 1                        | One `C` element is available on `out_data`               |
| `out_data`  | out       | `ACC_DW`                 | One signed element of result matrix `C`                  |
| `done`      | out       | 1                        | One-cycle pulse when the whole `A x B x C` sequence completes |

Data ordering: `A` is streamed row-major (`ROWS x K` elements), `B` is streamed row-major (`K x COLS` elements), and `C` is read back row-major (`ROWS x COLS` elements).

## FSM (Top-Level Control)

[#fsm-top-level-control](#fsm-top-level-control)

`systolic_array_top` is driven by a 5-state FSM:

```
IDLE --start--> LOAD_A --(ROWS*K elems)--> LOAD_B --(K*COLS elems)--> COMPUTE --sa_done--> OUTPUT --(ROWS*COLS elems)--> IDLE
```

| State     | Behavior                                                                 |
| --------- | --------------------------------------------------------------------------- |
| `IDLE`    | Waits for `start`; clears the internal PE accumulators for the next run.    |
| `LOAD_A`  | Accepts `ROWS*K` elements on `in_data` into matrix `A`.                    |
| `LOAD_B`  | Accepts `K*COLS` elements on `in_data` into matrix `B`, then triggers `systolic_array`. |
| `COMPUTE` | Waits for the `systolic_array` core to finish (`sa_done`).                 |
| `OUTPUT`  | Streams `ROWS*COLS` elements of `C` out on `out_data`.                     |

## Timing

[#timing](#timing)

The core compute latency of the systolic array itself is:

```
TOTAL_CYCLES = ROWS + COLS + K - 2
```

Total end-to-end latency additionally includes the `ROWS*K` cycles to load `A`, the `K*COLS` cycles to load `B`, and the `ROWS*COLS` cycles to stream out `C` (assuming the handshake is not stalled by `in_valid`/`out_ready`).

## Repository Structure

[#repository-structure](#repository-structure)

```
.
├── rtl/
│   ├── pe.v
│   ├── skew.v
│   ├── systolic_array.v
│   └── systolic_array_top.v
├── LICENSE
└── README.md
```

## Simulation

[#simulation](#simulation)

> A testbench for `systolic_array_top` will be added. General flow once available:

1. Compile the RTL and testbench with a Verilog simulator (e.g. Icarus Verilog, ModelSim/QuestaSim, or Vivado xsim).
2. Run the simulation and inspect the resulting waveform.
3. Check the `in_valid/in_ready` and `out_valid/out_ready` handshakes and the `done` pulse to verify functional correctness against a reference (e.g. NumPy) matrix multiplication.

Example with Icarus Verilog:

```bash
iverilog -o sim.out rtl/pe.v rtl/skew.v rtl/systolic_array.v rtl/systolic_array_top.v tb_systolic_array_top.v
vvp sim.out
```

## Results

[#results](#results)

*To be added: FPGA resource utilization (LUTs / FFs / DSPs / BRAM), maximum clock frequency, and CNN inference speedup/accuracy figures once synthesis and board-level testing are complete.*

## References

[#references](#references)

- H. T. Kung, "Why Systolic Architectures?", IEEE Computer, 1982.
- Google TPU / systolic-array-based accelerator literature.

## License

[#license](#license)

This project is licensed under the [MIT License](LICENSE).

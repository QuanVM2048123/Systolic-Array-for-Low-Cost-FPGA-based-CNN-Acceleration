# Systolic Array for Low-Cost FPGA-based CNN Acceleration

A lightweight, parameterizable **output-stationary systolic array** implemented in Verilog, designed to accelerate the matrix-multiplication core of CNN inference (e.g. im2col-based convolution / GEMM) on low-cost FPGA boards.

## Overview

Convolutional Neural Network (CNN) inference is dominated by matrix-multiplication workloads. A **systolic array** maps this computation onto a regular grid of simple Processing Elements (PEs) that pass data locally between neighbors, which keeps routing short and makes the design scale well on resource-constrained, low-cost FPGAs.

This project implements a **ROWS × COLS output-stationary systolic array** that computes:

```
C (ROWS x COLS) = A (ROWS x K) x B (K x COLS)
```

Each PE accumulates one output element of `C` locally and never moves it out of the array until the computation is complete, minimizing accumulator traffic and making the design well suited to fixed-point CNN accelerators.

## Architecture

### Output-Stationary Dataflow

- Matrix **A** streams into the array from the **left**, one skewed diagonal per cycle.
- Matrix **B** streams into the array from the **top**, one skewed diagonal per cycle.
- Each PE computes `acc += a_in * b_in`, then forwards `a_in` to the PE on its right and `b_in` to the PE below it.
- The partial sum `acc` (the output element `C[r][c]`) **stays stationary** inside PE `(r, c)` for the entire computation.

<img width="681" height="657" alt="image" src="https://github.com/user-attachments/assets/0094a10d-37ff-4b07-968e-5e3088f3708e" />


### Skewing

Because every PE needs its two operands to arrive on the same cycle *after* traveling different distances through the grid, the inputs must be **diagonally skewed** before entering the array. The `skew` module reshapes the flattened `A` and `B` matrices into per-row/per-column staggered streams (with `valid_a` / `valid_b` strobes), so row `r` of `A` and column `c` of `B` are released `r` and `c` cycles later, respectively.

## Module Description

| Module                 | File                    | Description                                                                                     |
| ----------------------- | ------------------------ | ------------------------------------------------------------------------------------------------- |
| `pe`                   | `rtl/pe.v`               | Single Processing Element: signed multiply-accumulate, registers `a`/`b` pass-through and `valid` pipeline, synchronous `clear`. |
| `skew`                 | `rtl/skew.v`             | Diagonally skews matrices `A` and `B` into per-row / per-column streams with `valid` strobes and a `done` flag. |
| `systolic_array`       | `rtl/systolic_array.v`   | Instantiates `skew` + a `ROWS x COLS` generate-block grid of `pe`, wires neighbor connections, packs the result into `C_flat`, and drives the compute-cycle counter / `done`. |
| `systolic_array_top`   | `rtl/systolic_array_top.v` | Top-level wrapper with a simple AXI-Stream-like handshake (`in_valid/in_ready`, `out_valid/out_ready`). A 5-state FSM streams matrix `A` and `B` in element-by-element, triggers the `systolic_array`, then streams matrix `C` out element-by-element. |

## Parameters

| Parameter | Default | Description                                              |
| --------- | ------- | ---------------------------------------------------------- |
| `ROWS`    | 4       | Number of rows in `A` / rows of PEs                       |
| `COLS`    | 4       | Number of columns in `B` / columns of PEs                 |
| `K`       | 4       | Shared (inner) dimension of `A` and `B`                   |
| `DW`      | 8       | Bit width of each element of `A` and `B` (signed)          |
| `ACC_DW`  | `2*DW + clog2(K)` | Accumulator / output bit width (signed), e.g. 18 bits for the defaults above |

All parameters are set at the top level (`systolic_array_top`) and propagate down to `systolic_array`, `skew`, and every `pe` instance via Verilog `parameter` overrides.

## Interface

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

## Target FPGA

- **Target Board:** EBAZ4205 Development Board
- **Clock Constraint:** 20 ns (50 MHz)


## References

- H. T. Kung, "Why Systolic Architectures?", IEEE Computer, 1982.
- Google TPU / systolic-array-based accelerator literature.

## License

This project is licensed under the [MIT License](LICENSE).

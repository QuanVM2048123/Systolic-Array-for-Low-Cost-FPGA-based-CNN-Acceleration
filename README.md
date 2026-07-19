# Systolic Array for Low-Cost FPGA-based CNN Acceleration

A modular Systolic Array-based Convolutional Neural Network (CNN) accelerator implemented in Verilog/SystemVerilog HDL, targeting low-cost FPGA platforms.

The project provides multiple systolic array configurations (e.g. Output-Stationary, Weight-Stationary) for convolution and matrix-multiplication acceleration, enabling architectural comparison in terms of FPGA resource utilization, throughput, and power efficiency on resource-constrained devices.

---

## Features

- Systolic Array-based Matrix Multiplication / Convolution
- Configurable Array Size (e.g. NxN Processing Elements)
- Support for Quantized Data Types (INT8 / INT16, optionally FP16)
- Weight-Stationary and/or Output-Stationary Dataflow
- On-chip Line Buffer / Weight Buffer for Data Reuse
- Modular RTL Architecture (PE array decoupled from control/buffering)
- FPGA-Oriented Resource & Timing Evaluation
- Low-Cost FPGA Target (small LUT/BRAM/DSP footprint)

---

## Project Overview

Systolic Array for Low-Cost FPGA-based CNN Acceleration
A Verilog hardware design implementing an N×N systolic array using an output-stationary dataflow, built to accelerate matrix multiplication — the core computation behind convolution and fully-connected layers in CNNs. The design targets low-cost FPGA platforms, aiming for efficient use of limited DSP resources.
Core architecture:

PE (Processing Element) – the basic compute unit, performing multiply-accumulate (MAC) operations and forwarding data to neighboring PEs.
Systolic Array – an N×N grid of PEs, where activations flow row-wise (left→right) and weights flow column-wise (top→bottom), maximizing data reuse between adjacent PEs.
Skew Buffer – delays input rows/columns by the appropriate number of cycles so data arrives at each PE in sync, forming the diagonal wavefront needed for correct systolic computation.
Top module – integrates the full pipeline: takes in raw input data, applies skewing automatically, feeds the systolic array, and outputs the accumulated results.

Highlights:

Fully parameterized (array size N, data width, accumulator width) for easy scaling
Modular design with clean separation between PE, array, and skew logic
Synchronous, DSP-friendly MAC implementation suitable for resource-constrained FPGAs
---

# Top-Level Architecture

<p align="center">
<img src="doc/images/Architecture_Block_Diagram.png" width="850">
</p>

# FPGA Evaluation

Target FPGA

- (e.g. Xilinx Zynq-7010 / Artix-7 / Lattice ECP5 — điền theo board thực tế)
- Development Board: ___
- Toolchain: Vivado / Quartus / Yosys, version ___

Clock Constraint

- ___ ns (___ MHz)

---

## Resource Utilization (example table — cập nhật số liệu thật sau khi synth)

| Configuration | LUT | FF | DSP | BRAM | WNS (ns) |
|--------------|----:|---:|----:|-----:|---------:|
| 4x4 Array | | | | | |
| 8x8 Array | | | | | |
| 16x16 Array | | | | | |

---

## Throughput / Performance (example table)

| Configuration | Clock Freq (MHz) | GOPS | Power (W) | GOPS/W |
|--------------|------------------:|-----:|----------:|-------:|
| 4x4 Array | | | | |
| 8x8 Array | | | | |
| 16x16 Array | | | | |

---

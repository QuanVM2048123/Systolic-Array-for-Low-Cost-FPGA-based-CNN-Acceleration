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

The accelerator integrates:

- Systolic PE Array (NxN Processing Elements)
- Activation Buffer (line buffer / FIFO)
- Weight Buffer
- Accumulator / Output Buffer
- Control Unit (FSM for load/compute/drain phases)

All modules interface through a shared control and data bus before producing the final feature map output.

---

# Processing Element (PE) Architecture

<p align="center">
<img width="1440" height="800" alt="image" src="https://github.com/user-attachments/assets/8df8d1cc-b5bc-4d40-8f94-d85c2ea8b58e" />

</p>

Dataflow per PE (example: Weight-Stationary)

```text
Load Weight (stationary)
      │
Receive Activation (from West)
      │
MAC (Multiply-Accumulate)
      │
Forward Activation (to East)
      │
Forward Partial Sum (to South)
```

---

# Systolic Array Dataflow

<p align="center">
<img src="doc/images/Architecture_Systolic_Dataflow.png" width="850">
</p>

Overall computation pipeline

```text
Weight Load Phase
      │
Activation Streaming
      │
MAC Propagation (row/column-wise)
      │
Partial Sum Accumulation
      │
Drain / Output Readout
      │
Quantization / Requantization
      │
Output Feature Map
```

---

# Repository Structure

```text
references/
│   └── README.md

report/
│   └── paper

rtl/
│   ├── pe.v
│   ├── skew.v
│   └── systolic_array.v

testbech/
│   └── pe

LICENSE
README.md
```

---

# Module Description

## Common Modules

| Module | Description |
|---------|-------------|
| cnn_defs | Global parameters (array size, data width, quantization) |
| quantizer | Requantization / activation scaling |
| accumulator | Partial sum accumulation and output packing |

---

## PE Array Modules

| Module | Function |
|---------|----------|
| pe_unit | Single Processing Element (MAC + forwarding registers) |
| pe_row | Row of PEs with horizontal/vertical interconnect |
| pe_array_top | Full NxN systolic array integration |

---

## Buffer / Control Modules

| Module | Function |
|---------|----------|
| activation_buffer | Line buffer feeding activations into the array |
| weight_buffer | Local weight storage feeding the array |
| addr_gen | Address generation for buffer read/write |
| fsm_controller | Load / Compute / Drain phase control |
| config_regs | Runtime configuration (kernel size, stride, etc.) |

---

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

## Experimental Observations

### PE Array

- (Ghi nhận về LUT/FF khi tăng kích thước mảng systolic)
- (Ảnh hưởng của array size đến tần số clock tối đa)
- (Trade-off giữa reuse dữ liệu và độ phức tạp buffer)

### System-Level

- (DSP usage theo kích thước mảng)
- (Bottleneck: buffer bandwidth vs PE compute throughput)
- (So sánh Weight-Stationary vs Output-Stationary nếu có triển khai cả hai)

---

# Future Work

- Support for Depthwise / Grouped Convolution
- Sparsity-aware Skipping (Zero-skipping)
- Mixed-Precision (INT4/INT8) Support
- On-chip Weight Compression
- Multi-layer Pipelining across Convolutional Layers
- Integration with a Full CNN Inference Pipeline (e.g. via RISC-V host)

---

# License

MIT License

---

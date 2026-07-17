# Systolic Array for Low-Cost FPGA-based CNN Acceleration

Design and implementation of a hardware accelerator based on a **Systolic Array** architecture to accelerate convolution operations in Convolutional Neural Networks (CNNs), targeting low-cost, resource-constrained FPGAs.

> ⚠️ **Project status:** Work in progress. This README is an architecture template/scaffold, to be updated once specific modules are finalized and Verilog code is pushed.

---

## Table of Contents

- [1. Introduction](#1-introduction)
- [2. Architecture Overview](#2-architecture-overview)
- [3. Block Diagram](#3-block-diagram)
- [4. Directory Structure](#4-directory-structure)
- [5. Environment Requirements](#5-environment-requirements)
- [6. Build & Simulation Guide](#6-build--simulation-guide)
- [7. Testing (Testbench)](#7-testing-testbench)
- [8. Results / Evaluation](#8-results--evaluation)
- [9. References](#9-references)
- [10. License](#10-license)

---

## 1. Introduction

Convolution accounts for most of the computation time and memory bandwidth in CNNs. The **Systolic Array** architecture leverages data reuse and pipelined dataflow between Processing Elements (PEs) to:

- Reduce off-chip memory accesses
- Increase computational throughput through parallelism
- Lower power consumption, making it suitable for low-cost FPGAs with limited DSP/BRAM resources

**Project goals:**
- [ ] Design a configurable-size systolic PE array
- [ ] Support at least one type of CNN layer (Conv2D), extensible to others (pooling, FC...)
- [ ] Optimize resource usage (LUT, DSP, BRAM) to fit on low-cost FPGAs (e.g., Xilinx Artix-7 / Intel Cyclone IV-V)
- [ ] Evaluate performance (operating frequency, throughput, power consumption)

---

## 2. Architecture Overview

> This section is a general scaffold — fill in the specifics once the team's actual design is finalized.

The system consists of the following main components:

| Component | Role |
|---|---|
| **Systolic PE Array** | Grid of Processing Elements (PEs), each performing a multiply-accumulate (MAC) operation, with data flowing in a pipeline between neighboring PEs |
| **Weight/Input Buffer** | Buffer (BRAM/FIFO) storing weights and image/feature map data before feeding the PE array |
| **Controller / FSM** | Controls dataflow, synchronizes weight loading, triggers computation, reads out results |
| **Output Accumulator** | Accumulates/writes convolution results to memory or the next layer |
| **Interface (AXI / custom)** | Interface between the accelerator and the host system (CPU/soft-core or DMA) |

**Dataflow (choose one, fill in once the design is finalized):**
- *Weight Stationary*: weights stay fixed in each PE while input data and results move through the array → reduces repeated weight memory reads.
- *Output Stationary*: partial sums stay fixed at each PE while input data and weights move through the array.
- *Row/Column Stationary*: combines reuse along rows or columns.

---

## 3. Block Diagram

```
                ┌─────────────────────────────┐
                │        Controller / FSM      │
                └───────┬──────────────┬──────┘
                        │              │
              ┌─────────▼───┐   ┌──────▼────────┐
              │ Weight Buffer│   │ Input Buffer   │
              │   (BRAM)     │   │   (BRAM)       │
              └─────────┬───┘   └──────┬────────┘
                        │              │
                ┌───────▼──────────────▼───────┐
                │                               │
                │        Systolic PE Array      │
                │   ┌────┬────┬────┬────┐       │
                │   │ PE │ PE │ PE │ PE │  ...  │
                │   ├────┼────┼────┼────┤       │
                │   │ PE │ PE │ PE │ PE │  ...  │
                │   └────┴────┴────┴────┘       │
                │                               │
                └───────────────┬───────────────┘
                                │
                        ┌───────▼────────┐
                        │ Output/Accum   │
                        │    Buffer      │
                        └───────┬────────┘
                                │
                        ┌───────▼────────┐
                        │  AXI/Interface │
                        └────────────────┘
```

*(This is a temporary ASCII diagram — replace with a proper diagram (draw.io / Visio / Vivado Block Design) and add the image to `docs/img/` once the architecture is finalized.)*

---

## 4. Directory Structure

```
.
├── README.md
├── LICENSE
├── rtl/                  # Verilog/SystemVerilog source code
│   ├── pe.v               # Processing Element
│   ├── systolic_array.v   # PE array
│   ├── controller.v       # Control FSM
│   ├── buffer.v           # Data buffer
│   └── top.v               # Top-level module
├── tb/                   # Testbenches
│   ├── tb_pe.v
│   ├── tb_systolic_array.v
│   └── tb_top.v
├── sim/                  # Simulation files, waveforms (.wcfg, .do)
├── constraints/          # Timing/pin constraint files (.xdc / .qsf)
├── docs/                 # Reports, block diagrams, design documentation
│   └── img/
└── scripts/              # Build scripts (TCL for Vivado/Quartus)
```

---

## 5. Environment Requirements

| Tool | Recommended Version | Notes |
|---|---|---|
| Xilinx Vivado | 2020.2 or later | If targeting Xilinx FPGAs (Artix-7, Zynq...) |
| Intel Quartus Prime | 20.1 or later | If targeting Intel FPGAs (Cyclone IV/V...) |
| ModelSim / QuestaSim | — | RTL simulation (optional; the bundled simulator in Vivado/Quartus also works) |
| Git | — | Source control |

---
## 8. Results / Evaluation

*(Fill in once actual synthesis results are available)*

| Metric | Value |
|---|---|
| Target FPGA | — |
| Max operating frequency (MHz) | — |
| LUT/FF/DSP/BRAM utilization | — |
| Power consumption (W) | — |
| Throughput (GOPS / images per second) | — |
| Accuracy vs. software model | — |

---

## 9. References

- H.T. Kung, "Why Systolic Architectures?", IEEE Computer, 1982.
- Papers on Systolic Array-based CNN acceleration on FPGA (add a specific list in `docs/`)

---

## 10. License

Released under the [MIT License](./LICENSE).

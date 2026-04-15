# Asynchronous FIFO Specification

## 1. Overview

The **async_fifo** design is a parameterizable asynchronous FIFO module. It uses separate clock domains for writing and reading, providing safe data transfer between two clock domains. The design employs dual-port memory and Gray-coded pointers for reliable synchronization.

### Key Features
1. Configurable data width and FIFO depth (determined by address width).
2. Separate write and read clocks.
3. Synchronization logic for pointers between clock domains.
4. Full and empty flags to indicate FIFO status.
5. Dual-port memory for simultaneous read and write.

## 2. Top-Level Module: `async_fifo`

### 2.1 Parameters

- **p_data_width** (default = 32)
  - Defines the width of data being transferred in/out of the FIFO.
- **p_addr_width** (default = 16)
  - Defines the width of the address pointers for the FIFO.
  - The FIFO depth will be \(2^{\text{p\_addr\_width}}\).

### 2.2 Ports

| **Port Name**       | **Direction** | **Width**                   | **Description**                                                         |
|---------------------|---------------|-----------------------------|-------------------------------------------------------------------------|
| `i_wr_clk`          | Input         | 1 bit                       | Write clock domain.                                                     |
| `i_wr_rst_n`        | Input         | 1 bit                       | Active-low reset signal for the write clock domain.                     |
| `i_wr_en`           | Input         | 1 bit                       | Write enable signal. When high and FIFO not full, data is written.      |
| `i_wr_data`         | Input         | `p_data_width` bits         | Write data to be stored in the FIFO.                                    |
| `o_fifo_full`       | Output        | 1 bit                       | High when FIFO is full and cannot accept more data.                     |
| `i_rd_clk`          | Input         | 1 bit                       | Read clock domain.                                                      |
| `i_rd_rst_n`        | Input         | 1 bit                       | Active-low reset signal for the read clock domain.                      |
| `i_rd_en`           | Input         | 1 bit                       | Read enable signal. When high and FIFO not empty, data is read out.     |
| `o_rd_data`         | Output        | `p_data_width` bits         | Read data from the FIFO.                                                |
| `o_fifo_empty`      | Output        | 1 bit                       | High when FIFO is empty and no data is available to read.               |

### 2.3 Internal Signals
- `w_wr_bin_addr` & `w_rd_bin_addr`
  - Binary write and read address buses.
- `w_wr_grey_addr` & `w_rd_grey_addr`
  - Gray-coded write and read address buses.
- `w_rd_ptr_sync` & `w_wr_ptr_sync`
  - Synchronized read pointer in the write domain and synchronized write pointer in the read domain, respectively.

### 2.4 Submodule Instantiations

#### 1. `read_to_write_pointer_sync`
Synchronizes the Gray-coded read pointer from the read clock domain to the write clock domain.

#### 2. `write_to_read_pointer_sync`
Synchronizes the Gray-coded write pointer from the write clock domain to the read clock domain.

#### 3. `wptr_full`
Handles the write pointer logic, updates the pointer upon valid writes, and detects FIFO full condition.

#### 4. `fifo_memory`
Dual-port RAM used to store the FIFO data. Supports simultaneous write and read using separate clocks.

#### 5. `rptr_empty`
Handles the read pointer logic, updates the pointer upon valid reads, and detects FIFO empty condition.

## 3. Submodules

This section describes each submodule in detail.

---

### 3.1 `fifo_memory`

#### 3.1.1 Parameters

- **p_data_width** (default = 32)  
  Width of each data word stored in the memory.
- **p_addr_width** (default = 16)  
  Width of the memory address ports. The depth of the memory is \(2^{\text{p\_addr\_width}}\).

#### 3.1.2 Ports

| **Port Name** | **Direction** | **Width**           | **Description**                                               |
|---------------|---------------|---------------------|---------------------------------------------------------------|
| `i_wr_clk`    | Input         | 1 bit               | Write clock.                                                  |
| `i_wr_clk_en` | Input         | 1 bit               | Write clock enable; when high, a write operation may occur.   |
| `i_wr_addr`   | Input         | `p_addr_width` bits | Address in memory where data will be written.                 |
| `i_wr_data`   | Input         | `p_data_width` bits | Data to be stored in the memory.                              |
| `i_wr_full`   | Input         | 1 bit               | FIFO full indicator (used to block writes when FIFO is full). |
| `i_rd_clk`    | Input         | 1 bit               | Read clock.                                                   |
| `i_rd_clk_en` | Input         | 1 bit               | Read clock enable; when high, a read operation may occur.     |
| `i_rd_addr`   | Input         | `p_addr_width` bits | Address in memory from where data will be read.               |
| `o_rd_data`   | Output        | `p_data_width` bits | Output data read from the memory.                             |

### 3.2 `read_to_write_pointer_sync`

#### 3.2.1 Parameters

- **p_addr_width** (default = 16)  
  Defines the address width (not counting the extra MSB bit used for indexing).

#### 3.2.2 Ports

| **Port Name**     | **Direction** | **Width**             | **Description**                                                                   |
|-------------------|---------------|-----------------------|-----------------------------------------------------------------------------------|
| `i_wr_clk`        | Input         | 1 bit                 | Write clock domain.                                                               |
| `i_wr_rst_n`      | Input         | 1 bit                 | Active-low reset for the write clock domain.                                      |
| `i_rd_grey_addr`  | Input         | `p_addr_width+1` bits | Gray-coded read pointer from the read clock domain.                               |
| `o_rd_ptr_sync`   | Output (reg)  | `p_addr_width+1` bits | Synchronized read pointer in the write clock domain (two-stage synchronization).  |
  
---

### 3.3 `write_to_read_pointer_sync`

#### 3.3.1 Parameters

- **p_addr_width** (default = 16)

#### 3.3.2 Ports

| **Port Name**     | **Direction** | **Width**             | **Description**                                                                 |
|-------------------|---------------|-----------------------|---------------------------------------------------------------------------------|
| `i_rd_clk`        | Input         | 1 bit                 | Read clock domain.                                                              |
| `i_rd_rst_n`      | Input         | 1 bit                 | Active-low reset for the read clock domain.                                     |
| `i_wr_grey_addr`  | Input         | `p_addr_width+1` bits | Gray-coded write pointer from the write clock domain.                           |
| `o_wr_ptr_sync`   | Output (reg)  | `p_addr_width+1` bits | Synchronized write pointer in the read clock domain (two-stage synchronization).|

### 3.4 `wptr_full`

#### 3.4.1 Parameters

- **p_addr_width** (default = 16)

#### 3.4.2 Ports

| **Port Name**     | **Direction** | **Width**             | **Description**                                                     |
|-------------------|---------------|-----------------------|---------------------------------------------------------------------|
| `i_wr_clk`        | Input         | 1 bit                 | Write clock.                                                        |
| `i_wr_rst_n`      | Input         | 1 bit                 | Active-low reset for the write clock domain.                        |
| `i_wr_en`         | Input         | 1 bit                 | Write enable signal.                                                |
| `i_rd_ptr_sync`   | Input         | `p_addr_width+1` bits | Synchronized read pointer from the read clock domain (Gray-coded).  |
| `o_fifo_full`     | Output (reg)  | 1 bit                 | Indicates when the FIFO is full.                                    |
| `o_wr_bin_addr`   | Output (wire) | `p_addr_width` bits   | Binary write address used for indexing the memory.                  |
| `o_wr_grey_addr`  | Output (reg)  | `p_addr_width+1` bits | Gray-coded write pointer.                                           |

---

### 3.5 `rptr_empty`

#### 3.5.1 Parameters

- **p_addr_width** (default = 16)

#### 3.5.2 Ports

| **Port Name**     | **Direction** | **Width**             | **Description**                                                       |
|-------------------|---------------|-----------------------|-----------------------------------------------------------------------|
| `i_rd_clk`        | Input         | 1 bit                 | Read clock domain.                                                    |
| `i_rd_rst_n`      | Input         | 1 bit                 | Active-low reset for the read clock domain.                           |
| `i_rd_en`         | Input         | 1 bit                 | Read enable signal.                                                   |
| `i_wr_ptr_sync`   | Input         | `p_addr_width+1` bits | Synchronized write pointer from the write clock domain (Gray-coded).  |
| `o_fifo_empty`    | Output (reg)  | 1 bit                 | Indicates when the FIFO is empty.                                     |
| `o_rd_bin_addr`   | Output (wire) | `p_addr_width` bits   | Binary read address used for indexing the memory.                     |
| `o_rd_grey_addr`  | Output (reg)  | `p_addr_width+1` bits | Gray-coded read pointer.                                              |

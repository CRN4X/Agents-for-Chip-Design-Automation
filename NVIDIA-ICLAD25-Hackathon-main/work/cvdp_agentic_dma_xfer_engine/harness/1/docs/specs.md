# DMA Transfer Engine Module Description

This module implements a configurable Direct Memory Access (DMA) engine. It autonomously transfers data from a source address to a destination address without continuous CPU intervention. The `dma_xfer_engine` supports configurable transfer sizes (byte, halfword, word) and optional address auto-increment for both source and destination. It provides status via a control register and can be commanded via a simple slave interface, while issuing master bus requests to read and write from system memory.

---

## Parameterization

- **TRANSFER_SIZE_ENCODING:**
  - `DMA_B`  = 2'b00 (Byte transfer)
  - `DMA_HW` = 2'b01 (Halfword transfer)
  - `DMA_W`  = 2'b10 (Word transfer)

- **CONTROL_REGISTER_WIDTH:** 10 bits  
  The control register contains fields for transfer count, transfer size (source/destination), and increment enables.

- **ADDRESS_WIDTH:** 32 bits  
  The source and destination addresses are 32-bit wide.

- **DATA_WIDTH:** 32 bits  
  The data bus width (read/write data) is 32 bits.

These parameters define how the DMA transfer sizes are encoded, and the bit-widths for addresses, data, and control fields.

---

## Interfaces

### Clock and Reset

- **clk:**  
  System clock input. All internal logic is synchronized to the rising edge of `clk`.

- **rstn:**  
  Active-low reset input. When deasserted, all registers (control register, source address, destination address, and internal FSM state) are cleared.

### Control Signals

- **addr** (4 bits):  
  Slave address input for register selection (e.g., 0x0 for the control register, 0x4 for the source address, 0x8 for the destination address).

- **we:**  
  Write-enable signal for the slave interface. When high, the data on `wd` is written to the selected register.

- **wd** (32 bits):  
  Write data for the slave interface.

- **rd** (32 bits):  
  Read data output for the slave interface. When a read occurs (i.e., `we = 0`), the module drives this bus with the contents of the selected register.

### DMA Input Data

- **dma_req:**  
  A request input from system logic or software indicating that a DMA transfer should begin. On the next cycle, the `dma_xfer_engine` sets up its internal state machine for read/write operations.

- **bus_grant:**  
  A signal from the bus arbiter indicating that the `dma_xfer_engine` has been granted access to the system bus.

- **rd_m** (32 bits):  
  Data returned from the system bus during a read operation. The `dma_xfer_engine` captures this data into an internal buffer before writing it out to the destination.

### DMA Output Data

- **bus_req:**  
  Asserted by the `dma_xfer_engine` to request the bus from an arbiter. It remains asserted until the transfer is complete or until the module relinquishes control.

- **bus_lock:**  
  When asserted, it indicates that the `dma_xfer_engine` desires uninterrupted bus access for the duration of the transfer, preventing preemption.

- **addr_m** (32 bits):  
  The address output for system bus transactions (either read or write).

- **we_m:**  
  Master write-enable. When high, the `dma_xfer_engine` drives data onto `wd_m` for writing to memory. When low, the module reads from memory.

- **wd_m** (32 bits):  
  Data driven onto the system bus for writes.

- **size_m** (2 bits):  
  Encoded transfer size for the system bus transaction (byte, halfword, or word).

---

## Detailed Functionality

### 1. Configuration Registers and Internal Storage

1. **Control Register (DMA_CR):**  
   - Holds transfer count (`cnt`), source transfer size, destination transfer size, increment-enable bits for source/destination, and additional flags (e.g., `line_en`).
   - Written via the slave interface when `we` is asserted and `addr` = DMA_CR address (0x0).
   - Read out on `rd` when `addr` = DMA_CR and `we` is deasserted.

2. **Source Address Register (DMA_SRC_ADR):**  
   - Stores the starting source address for the DMA transfer.
   - Written via the slave interface when `we` is asserted and `addr` = 0x4.
   - Read out on `rd` when `addr` = 0x4 and `we` is deasserted.

3. **Destination Address Register (DMA_DST_ADR):**  
   - Stores the starting destination address for the DMA transfer.
   - Written via the slave interface when `we` is asserted and `addr` = 0x8.
   - Read out on `rd` when `addr` = 0x8 and `we` is deasserted.

### 2. State Machine (FSM)

- **IDLE State:**  
  The `dma_xfer_engine` waits for a `dma_req` assertion. Upon seeing it, the module drives `bus_req` and transitions to a wait-for-grant phase.

- **WB (Wait-for-Bus) State:**  
  The `dma_xfer_engine` asserts `bus_req` (and `bus_lock` if needed) until the bus arbiter asserts `bus_grant`. Then the FSM transitions to the transfer state.

- **TR (Transfer) State:**  
  The FSM alternates between read and write sub-phases:
  1. **Read Phase:**  
     - Drive `addr_m` = current source address and `we_m` = 0. Capture returned data in an internal buffer.
     - Increment source address if `inc_src` is set.
  2. **Write Phase:**  
     - Drive `addr_m` = current destination address and `we_m` = 1. Drive the captured data onto `wd_m`.
     - Increment destination address if `inc_dst` is set.
  - Update an internal counter for each completed read/write pair. If `cnt` is reached, release `bus_req`/`bus_lock` and return to IDLE.

### 3. Address Incrementation

Depending on the configured source/destination size (byte, halfword, or word), the module increments the respective address by 1, 2, or 4 bytes after each corresponding read or write phase, if the increment-enable bit is set.

### 4. Transfer Size and Data Packing

- **Read Data Packing:**  
  Based on `size_m` and the current offset in the source address’s lower bits, the `dma_xfer_engine` extracts the relevant byte(s) from `rd_m`.

- **Write Data Packing:**  
  The `dma_xfer_engine` similarly repacks data into the correct byte lanes of `wd_m` if the destination size is smaller than a word.

### 5. Slave Read Logic

When a read occurs (i.e., `we = 0` on the slave side), the module drives `rd` based on `addr`. For unrecognized addresses, it returns 0.

---

## Summary

The `dma_xfer_engine` automates memory-to-memory transfers with minimal CPU overhead. A host processor (or other system logic) writes to the module’s configuration registers (source/destination addresses, control register), then asserts `dma_req` to start a transfer. The FSM requests and locks the bus, performs read bursts from the source, writes to the destination, and handles address incrementing according to the configured transfer size. Once the specified transfer count is reached, the engine goes idle and releases the bus. By allowing byte, halfword, or word transfers with flexible increment behavior, this module provides a robust solution for offloading bulk data moves in embedded systems.
# AXI4Lite to PCIe Config Module (`axi4lite_2_pcie_cfg_bridge.sv`)

## Overview
The `axi4lite_to_pcie_cfg_bridge` module is a bridge that translates `AXI4-Lite` write transactions into PCIe Configuration Space write transactions. It acts as an interface between an `AXI4-Lite master` (e.g., a processor) and the `PCIe Configuration Space`, enabling the master to configure PCIe devices by writing to their `configuration registers`.
The module is designed as a Finite State Machine (FSM) to handle the sequence of operations required for `AXI4-Lite` to `PCIe Configuration Space` translation. It supports byte-level writes using the `AXI4-Lite` write strobe (wstrb) and ensures proper handshaking with both the `AXI4-Lite` and `PCIe` interfaces.

## Read Transaction Support
The `axi4lite_to_pcie_cfg_bridge` module supports AXI4-Lite read transactions in addition to write transactions. The read functionality allows the AXI4-Lite master to fetch configuration data from the PCIe Configuration Space. This ensures that the master can both configure and retrieve settings from PCIe devices.

The read process follows the AXI4-Lite protocol, ensuring proper handshaking between the master and the bridge. When a read request is initiated, the module retrieves data from the PCIe Configuration Space and returns it to the AXI4-Lite master while following all protocol timing and response requirements.

---

## Parameterization

This module is fully parameterized, allowing flexibility in configuring **data width, address width**.

- **`DATA_WIDTH`**: Configures the bit-width of data. Default value is **32 bits**.
  - The width of the AXI4-Lite data bus (`wdata`) and PCIe Configuration Space data (`pcie_cfg_wdata` and `pcie_cfg_rdata`).
- **`ADDR_WIDTH`**: Determines the config memory size by specifying the number of address bits. Default value is **8 bits**.
  - The width of the AXI4-Lite address bus (`awaddr`) and PCIe Configuration Space address (`pcie_cfg_addr`).

---

## Interfaces

### AXI4-Lite Interface

## Clock and Reset Signals

- **`aclk(1-bit, Input)`**: AXI4-Lite clock signal.
- **`aresetn(1-bit, Input)`**: Input	AXI4-Lite active-low reset signal. When deasserted (`0`), it resets the logic outputs to zero.

## Inputs 
- **`awaddr(8-bit, Input)`**:	AXI4-Lite write address. Specifies the target address for the write operation.
- **`awvalid(1-bit, Input)`**: AXI4-Lite write address valid signal. Indicates that awaddr is valid.
- **`wdata(32-bit, Input)`**: AXI4-Lite write data. Contains the data to be written.
- **`wstrb(4-bit, Input)`**: AXI4-Lite write strobe. Specifies which bytes of wdata are valid.
- **`wvalid(1-bit, Input)`**: AXI4-Lite write data valid signal. Indicates that wdata and wstrb are valid.
- **`bready(1-bit, Input)`**: AXI4-Lite write response ready signal. Indicates that the master is ready to accept the response.
- **`araddr(8-bit, Input)`**: AXI4-Lite read address. Specifies the address of the data to be read.
- **`arvalid(1-bit, Input)`**: AXI4-Lite read address valid signal. Indicates that `araddr` is valid.
- **`rready(1-bit, Input)`**: AXI4-Lite read data ready signal. Indicates that the master is ready to receive the read data.

## Outputs
- **`awready(1-bit, Output)`**: AXI4-Lite write address ready signal. Indicates that the bridge is ready to accept the address.
- **`wready(1-bit, Output)`**: AXI4-Lite write data ready signal. Indicates that the bridge is ready to accept the data.
- **`bresp(2-bit, Output)`**: AXI4-Lite write response. Indicates the status of the write transaction (e.g., OKAY).
- **`bvalid(1-bit, Output)`**: AXI4-Lite write response valid signal. Indicates that bresp is valid.
- **`arready(1-bit, Output)`**: AXI4-Lite read address ready signal. Indicates that the bridge has accepted the read address.
- **`rdata(32-bit, Output)`**: AXI4-Lite read data. Contains the data read from the PCIe Configuration Space.
- **`rresp(2-bit, Output)`**: AXI4-Lite read response. Indicates the status of the read transaction (e.g., OKAY).
- **`rvalid(1-bit, Output)`**: AXI4-Lite read response valid signal. Indicates that `rdata` and `rresp` are valid.
  
### PCIe Configuration Space Interface
## Inputs 
- **`pcie_cfg_rdata(32-bit, Input)`**:	PCIe Configuration  read data. Contains the data read from the target register.
- **`pcie_cfg_rd_en(1-bit, Input)`**:	PCIe Configuration  read enable signal. Indicates a valid read transaction.

## Outputs
- **`pcie_cfg_addr(8-bit, Output)`**:	PCIe Configuration  address. Specifies the target register address.
- **`pcie_cfg_wdata(32-bit, Output)`**:	PCIe Configuration  write data. Contains the data to be written.
- **`pcie_cfg_wr_en(1-bit, Output)`**:	PCIe Configuration  write enable signal. Indicates a valid write transaction.

---
## Detailed Functionality
### Finite State Machine (FSM)
  - The module operates as a 5-state FSM to handle AXI4-Lite write transactions:

  **IDLE**:
  - Waits for both `awvalid` and `wvalid` to be asserted, indicating a valid write transaction.
  - Transitions to `ADDR_CAPTURE` when a write transaction is detected.

  **ADDR_CAPTURE**:
  - Captures the AXI4-Lite write address (`awaddr`) into an internal register (`awaddr_reg`).
  - Asserts `awready` to indicate that the address has been accepted.

### Transitions to DATA_CAPTURE
  **DATA_CAPTURE**:
  - Captures the AXI4-Lite write data (`wdata`) and write strobe (`wstrb`) into internal registers (`wdata_reg` and `wstrb_reg`).
  - Asserts `wready` to indicate that the data has been accepted.

### Transitions to PCIE_WRITE
  **PCIE_WRITE**:
  - Asserts `pcie_cfg_wr_en` to initiate a PCIe Configuration Space write.
  - Drives `pcie_cfg_addr` with the captured address (`awaddr_reg[7:0]`).
  - Drives `pcie_cfg_wdata` with the captured data (`wdata_reg`), applying the write strobe (`wstrb_reg`) to update only the selected bytes.

### Transitions to SEND_RESPONSE
  **SEND_RESPONSE**:
  - Asserts `bvalid` to indicate that the write response (`bresp`) is valid.
  - Drives `bresp` with 2'b00 (`OKAY`) to indicate a successful write.
  - Waits for `bready` to be asserted by the AXI4-Lite master.
  - Transitions back to `IDLE` after the response is accepted.

### Byte-Level Write Handling
  - The module uses the `AXI4-Lite` write strobe (`wstrb`) to selectively update bytes in the `PCIe Configuration Space`. For example:
  - If `wstrb` = 4'b0011, only the lower 16 bits of wdata are written to the target register.
  - The remaining bits are preserved by using the current value of `pcie_cfg_rdata`.

## Finite State Machine (FSM) for Read Transactions
The module includes following states in the FSM to handle AXI4-Lite read transactions:
  **IDLE**
  - Waits for `arvalid` to be asserted, indicating a valid read transaction.
  - Transitions to `ADDR_CAPTURE` when a read request is detected.

  **ADDR_CAPTURE**
  - Captures the AXI4-Lite read address (`araddr`) into an internal register.
  - Asserts `arready` to indicate that the address has been accepted.

  **PCIE_READ**
  - Asserts `pcie_cfg_rd_en` to initiate a PCIe Configuration Space read.
  - Drives `pcie_cfg_addr` with the captured read address (`araddr_reg[7:0]`).
  - Waits for valid data from the PCIe Configuration Space.

  **SEND_RESPONSE**
  - Asserts `rvalid` to indicate that the read response (`rresp`) and read data (`rdata`) are valid.
  - Waits for `rready` to be asserted by the AXI4-Lite master.
  - Transitions back to `IDLE` after the response is accepted.

## Example Usages (Write)
 ### Example 1: Writing to a PCIe Configuration Register
   ### The AXI4-Lite master drives:
  - awaddr = 32'h0000_0010
  - wdata = 32'hDEAD_BEEF
  - wstrb = 4'b1111 (write all 4 bytes)
  - awvalid = 1 and wvalid = 1

  **The bridge:**
  - Captures the address and data.
  - Writes 0xDEADBEEF to the `PCIe Configuration Space` register at address 0x10.
  - Sends an `OKAY` response to the `AXI4-Lite master`.

 ### Example 2: Partial Write to a PCIe Configuration Register
   ### The AXI4-Lite master drives:
  - awaddr = 32'h0000_0020
  - wdata = 32'h1234_5678
  - wstrb = 4'b0011 (write only the lower 2 bytes)
  - awvalid = 1 and wvalid = 1

  **The bridge:**
  - Captures the address and data.
  - Writes 0x5678 to the lower 16 bits of the `PCIe Configuration Space` register at address 0x20.
  - Preserves the upper 16 bits of the register.
  - Sends an `OKAY` response to the `AXI4-Lite master`.

## Example Usages (Read)
 ### Example 1: Reading from a PCIe Configuration Register
 #### The AXI4-Lite master drives:
  - `araddr` = 32'h0000_0010
  - `arvalid` = 1

 #### The bridge:
  - Captures the address.
  - Initiates a PCIe Configuration Space read.
  - Receives data (e.g., 0xDEADBEEF) from the PCIe Configuration Space.
  - Sends `rdata` = 32'hDEAD_BEEF and `rresp` = OKAY to the AXI4-Lite master.

## Summary
The `axi4lite_to_pcie_cfg_bridge` module provides a robust and efficient interface for translating AXI4-Lite write transactions into PCIe Configuration Space write transactions. Its FSM-based design ensures proper handshaking and byte-level write support, making it suitable for configuring PCIe devices in embedded systems. With the read support, the `axi4lite_to_pcie_cfg_bridge` module now fully supports bidirectional data flow between AXI4-Lite and PCIe Configuration Space. This enhancement allows software to not only configure PCIe devices but also retrieve their current settings. The FSM-based design ensures protocol compliance and efficient transaction handling.

## Key Features:
- Supports AXI4-Lite write transactions.
- Handles byte-level writes using the AXI4-Lite write strobe (wstrb).
- Implements a 5-state FSM for reliable operation.
- Provides proper handshaking with both AXI4-Lite and PCIe interfaces.
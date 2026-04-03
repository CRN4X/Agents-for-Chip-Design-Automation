# PCIe Endpoint Module (`pcie_endpoint.sv`)

## Overview
The `pcie_endpoint` module implements a PCIe endpoint logic block that:
- Receives and processes PCIe Transaction Layer Packets (TLPs),
- Initiates and monitors DMA transfers,
- Triggers MSI-X interrupts on DMA completion.

It is architected using multiple finite state machines (FSMs) to separate concerns and ensure robust design: one FSM each for PCIe transaction management, data link layer coordination, DMA handling, and interrupt generation.

---

## Parameterization

| Parameter     | Description                                  | Default |
|---------------|----------------------------------------------|---------|
| `ADDR_WIDTH`  | Bit-width of the DMA address signals         | 64      |
| `DATA_WIDTH`  | Bit-width of the PCIe and DMA data bus       | 128     |

These parameters enable adaptation to various PCIe configurations and host systems.

---

## Interfaces

### Clock and Reset
| Signal   | Direction | Width | Description                            |
|----------|-----------|-------|----------------------------------------|
| `clk`    | Input     | 1     | Clock signal for synchronous logic     |
| `rst_n`  | Input     | 1     | Active-low reset                       |

### PCIe Interface
| Signal           | Direction | Width         | Description                                     |
|------------------|-----------|---------------|-------------------------------------------------|
| `pcie_rx_tlp`    | Input     | `DATA_WIDTH`  | Incoming PCIe TLP data                          |
| `pcie_rx_valid`  | Input     | 1             | Indicates `pcie_rx_tlp` contains valid data     |
| `pcie_rx_ready`  | Output    | 1             | Indicates endpoint is ready to receive TLP      |
| `pcie_tx_tlp`    | Output    | `DATA_WIDTH`  | Outgoing PCIe TLP data                          |
| `pcie_tx_valid`  | Output    | 1             | Indicates valid TLP data on `pcie_tx_tlp`       |
| `pcie_tx_ready`  | Input     | 1             | Indicates host is ready to accept outgoing TLP  |

### DMA Interface
| Signal         | Direction | Width | Description                                 |
|----------------|-----------|-------|---------------------------------------------|
| `dma_request`  | Input     | 1     | Request to initiate a DMA transfer          |
| `dma_complete` | Output    | 1     | Indicates that DMA operation is complete    |

### MSI-X Interrupt Interface
| Signal           | Direction | Width | Description                                     |
|------------------|-----------|-------|-------------------------------------------------|
| `msix_interrupt` | Output    | 1     | MSI-X interrupt generated after DMA completion  |

---

## Internal Signals

| Signal             | Width        | Description                                         |
|--------------------|--------------|-----------------------------------------------------|
| `tlp_decoded_data` | `DATA_WIDTH` | Latched copy of received PCIe TLP                   |
| `tlp_valid`        | 1            | Indicates valid TLP is available for processing     |
| `dma_address`      | `ADDR_WIDTH` | Address for DMA operation                           |
| `dma_data`         | `DATA_WIDTH` | Data for DMA write operation                        |
| `dma_start`        | 1            | Trigger signal to begin DMA                         |

---

## Functional Description

### PCIe Transaction FSM (`pcie_transaction_fsm`)
Handles incoming PCIe TLPs:
- **States**: `IDLE`, `RECEIVE`, `PROCESS`, `SEND_RESPONSE`
- When a TLP is received (`pcie_rx_valid`), the FSM transitions to `RECEIVE`, captures the data, and marks it valid.
- In `PROCESS`, it may trigger DMA or other logic.
- In `SEND_RESPONSE`, it transitions to data link FSM for sending a response.

### PCIe Data Link FSM (`pcie_data_link_fsm`)
Manages transmission of TLPs over PCIe:
- **States**: `DLL_IDLE`, `TRANSMIT`, `WAIT_ACK`, `RETRY`
- When valid TLP data is ready, FSM asserts `pcie_tx_valid` and waits for `pcie_tx_ready`.
- Retries transmission if not acknowledged.

### DMA FSM (`dma_fsm`)
Performs memory operations via DMA engine:
- **States**: `DMA_IDLE`, `READ_DESC`, `FETCH_DATA`, `WRITE_DMA`
- On `dma_request`, begins reading descriptors and fetching data.
- Once data is written to the target, it asserts `dma_complete`.

### MSI-X FSM (`msix_fsm`)
Generates interrupts after DMA:
- **States**: `MSIX_IDLE`, `GENERATE_INT`
- Monitors `dma_complete`, and upon detection, asserts `msix_interrupt` for one clock cycle.

---

## Timing and Handshake Behavior

- **`pcie_rx_ready`** is high only when the module is in `IDLE` state and ready to receive.
- **`pcie_tx_valid`** is asserted when in `TRANSMIT` state and remains high until `pcie_tx_ready` is received.
- **`dma_complete`** and **`msix_interrupt`** are single-cycle pulses triggered by respective FSM transitions.

---

## Summary

The `pcie_endpoint` is a modular and FSM-driven PCIe endpoint logic capable of:

- Accepting and decoding PCIe TLPs.
- Coordinating DMA data transfers using descriptors.
- Sending completion or response TLPs.
- Triggering MSI-X interrupts for host notification.

### Key Features:
- Parameterized for address and data width.
- Separated FSMs for clean logic partitioning.
- PCIe TLP RX/TX handshake compliant.
- Single-cycle MSI-X interrupt signaling.
- Scalable for integration with full PCIe/DMA systems.
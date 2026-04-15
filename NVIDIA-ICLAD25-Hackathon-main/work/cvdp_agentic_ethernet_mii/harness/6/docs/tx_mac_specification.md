# Ethernet MAC TX Module Specification Document

## 1. Introduction

The **Ethernet MAC TX Module** is designed to handle Ethernet frame transmission within a network interface. It interfaces with a configuration register block, dual-port memory for buffering transmit data, and an AXI-stream output for delivering the frame data to downstream logic. This module supports configuration updates through a register interface, manages a simple state machine for frame transmission, and generates an interrupt upon completion of a transmission sequence.

## 2. Functional Overview

The module orchestrates Ethernet frame transmission using a combination of configuration registers, a dedicated dual-port memory (implemented by an internal **DP-RAM**), and an internal state machine. The following major functions are implemented:

- **Configuration Interface:**  
  Allows external logic to program frame parameters, including transmit length, control/status signals, and interrupt enable. Data writes to a memory-mapped space configure both the transmit RAM (for frame payload) and various control registers.
  
- **Memory Access:**  
  A dual-port RAM is instantiated to store the transmit frame data. One port is used for configuration writes and reads (by the control logic) and the transmit engine uses the other to read data sequentially during transmission.

- **State Machine for Transmission:**  
  The transmit engine operates as a finite-state machine (FSM) with four states:
  - First State, Waits for a start condition defined by a transmit control register.
  - Second State, reads data from the transmit memory and asserts valid output until a transmission condition is met.
  - Third State, Updates counters and manages address pointers while checking if the entire frame has been transmitted.
  - Final State: Concludes the current transmission session by clearing control flags(BUSY and PROGRAM) and returning to idle.
  
- **Data Formatting and Padding:**  
  The module ensures that each Ethernet frame is at least 64 bytes long. If the programmed length is below 64, the module pads the transmitted data with zeroes. The word-level transmission uses valid byte strobes that are dynamically computed based on the remaining data to be sent.

- **Interrupt Generation:**  
  In normal frame transfer, on completion of a frame transfer, if enabled by a dedicated control register, an interrupt is asserted to indicate the end of transmission. In MAC address update mode, an interrupt is asserted to indicate the completion of the address update. Sections below explain both these modes and their operation.

## 3. Module Interface

The top-level module is defined as follows:

```verilog
module ethernet_mac_tx
(
    input            clk_in,            // System clock for transmit logic
    input            rst_in,            // Asynchronous reset, active high

    // Configuration Register Interface
    input            cfg_wr_in,         // Configuration write enable
    input  [31:0]    cfg_addr_in,       // Configuration register address
    input  [31:0]    cfg_data_wr_in,    // Configuration data write bus
    output [31:0]    cfg_data_rd_out,   // Configuration data read bus

    output           interrupt_out,     // Interrupt output signal

    // AXI-stream TX Output Interface
    output           axis_tvalid_out,   // Output valid flag
    output [31:0]    axis_tdata_out,    // Transmit data bus (32-bit)
    output [3:0]     axis_tstrb_out,    // Byte strobe indicating valid bytes in tdata
    output           axis_tlast_out,    // Indicates the last data word of frame
    input            axis_tready_in     // Downstream ready signal
);
```

### Port Descriptions

- **clk_in:**  
  Rising edge triggered Primary clock for the transmit logic and dual-port RAM access.

- **rst_in:**  
  Active-high asynchronous reset that initializes internal registers and state.

- **Configuration Interface Signals:**  
  - **cfg_wr_in:** Active HIGH. When asserted, it indicates a write to one of the configuration registers or memory space.  
  - **cfg_addr_in [31:0]:** Provides the address for configuration. Certain addresses are mapped to transmit length, control, and interrupt enable registers.  
  - **cfg_data_wr_in [31:0]:** Contains data for writing configuration registers.  
  - **cfg_data_rd_out [31:0]:** Data read back from the registers or memory location.
  
- **Interrupt Output:**  
  - **interrupt_out:** Active HIGH. Asserted when an AXI transmit operation has ended and the interrupt enable is active.

- **AXI-Stream Interface Signals:**  
  - **axis_tvalid_out:** Active HIGH. Indicates that transmit data transmitted on **axis_tdata_out** is valid.  
  - **axis_tdata_out [31:0]:** The 32-bit transmit data word read from the transmit memory.  
  - **axis_tstrb_out [3:0]:** Active HIGH. A strobe that flags which bytes in **axis_tdata_out** are valid.  
  - **axis_tlast_out:** Active HIGH. Marks the last word of the frame; used downstream to signal end-of-frame.  
  - **axis_tready_in:** Active HIGH. Input signal indicating that the receiving logic is ready to accept data.

## 4. Functional Details


### 4.1 Configuration Registers and Memory Mapping

The Ethernet MAC TX module splits its configuration and frame data storage into two main parts: configuration registers and transmit data memory. The configuration registers allow external control logic (for example, a host processor) to set up various transmission parameters, while a dedicated memory block stores the actual frame data to be sent. Memory accesses must be 32-bit word-aligned. Only the upper address bits are used to select memory locations; the lower address bits are ignored. Unaligned accesses are not supported. 

#### **Configuration Registers**

These registers are memory-mapped at fixed addresses and can be written by an external controller. When an address below **0x00001000** is accessed for writing, the module interprets the data as destined for the frame buffer memory. Specific registers accessible via their lower 16-bit addresses include:

1. **Transmit Length Register (Address 0x07F4)**  
   - **Purpose:** This register is used to set the intended length of the Ethernet frame. This length includes the MAC 12-byte address as well.   
   - **Functionality[15:0]:** The configured frame length defines how many bytes will be transmitted during a frame transfer. To meet Ethernet specifications, the module enforces a minimum frame length of 64 bytes. If the host programs a value lower than 64, the module will automatically pad the frame with zeroes so that the minimum length is met. Using the configuration interface, cfg_data_wr_in[15:0] is written to address 0x07F4 to update the frame length.
   
2. **Interrupt Enable Register (Address 0x07F8)**  
   - **Purpose:** This register controls whether the transmitter should issue an interrupt when the frame transmission is complete.  
   - **Functionality:** When the interrupt enable bit is set, the module asserts an interrupt signal at the end of each transmission. This interrupt can inform the processor or controlling entity that the frame has been fully transmitted, making it possible to trigger further actions or start the transmission of another frame. 0x00000001 is written to address 0x7F8 to enable interrupt output.

3. **Transmit Control Register (Address 0x07FC)**  
   - **Purpose:** This register governs the overall operation of the transmit process and communicates the current transmission status.  
   - **Key Control Bits:**
     - **Program Mode Bit[1]:** This bit instructs the transmitter to enter a special mode when activated. In this mode, the normal data stream is bypassed, and the module immediately only updates the Destination MAC Address. This behavior can be useful for transmitting the same data with a different Destination MAC address. 0x00000002 is written to address 0x7FC to enable the MAC address only Function.
     - **Busy Bit[0]:** This bit indicates that a transmission is in progress. It serves as a status flag to help prevent new configurations from taking effect during an ongoing transmission cycle. 0x00000001 is written to address 0x7FC to start AXI transmission.

#### **Dual-Port Transmit Memory**

In addition to the configuration registers, the module makes use of a dual-port memory block dedicated to storing the frame data:

- **Usage:**  
  The memory holds 32-bit words that collectively form the Ethernet frame to be transmitted. Because Ethernet frames are loaded into this memory before transmission, it is possible to modify or update the frame content without interfering with the transmit process itself. The design effectively uses a read-first behavior.

- **Dual-Port Functionality:**  
  The memory is partitioned into two access channels:
  - **Port0 (Configuration Write and Read):**  
    When the external controller issues a write operation to an address below **0x00001000**, the data provided is saved into the transmit memory. This allows the frame data to be pre-loaded into the buffer.
  - **Port1 (Transmit Read):**  
    During the transmission phase, the module reads the pre-loaded frame data sequentially from this memory. The content is then pushed onto the AXI-stream interface that ultimately drives the transmission process. The dual-port design ensures that data loading and readout operations can occur independently and concurrently, maximizing throughput and minimizing potential data clashes.

### 4.2 Internal State Machine Flow

The transmitter follows a four-phase process to deliver an Ethernet frame. These phases are described as follows:

1. **Initial Phase (Idle):**  
   - **Purpose:**  
     The transmitter waits for an external command to begin frame transmission.
   - **Operation:**  
     It monitors the control interface for a transmission request. Once a request is detected, the controller checks if a special programming mode is active. If that mode is enabled, the transmitter skips normal data streaming and moves directly to termination; otherwise, it transitions into the next phase.

2. **Data Transfer Phase (Read):**  
   - **Purpose:**  
     This phase is dedicated to updating internal tracking of the frame transmission, and the transmitter streams the actual frame data.
   - **Operation:**  
     At the end of a data transfer cycle, the controller:
     - **Decrements the Remaining Data Count:**  
       A counter representing the number of bytes left to transmit is reduced by the size of one data word (typically 4 bytes).  
     - **Advances the Data Pointer:**  
       The pointer to the memory buffer is incremented so that the next word of data can be read in the subsequent cycle.
     
3. **Pause Phase:**  
   - **Purpose:**  
     In this phase, the transmitter holds the axi transmission.
   - **Operation:**  
     The transmitter continuously checks whether the downstream receiver is ready to accept data. Two conditions can trigger a temporary halt in data streaming:
     - **Downstream Pause:** If the receiver signals it cannot accept more data (its ready indicator is low), the data output is temporarily paused.
     - **Toggle Behavior:**  If the receiver’s ready signal (`axis_tready_in`) is low, or if the current data word is the last segment of the frame, the FSM transitions from the Data Transfer Phase (Read) to the Pause Phase. This results in a toggling behavior: on one cycle, the transmitter may move to the Pause Phase to update status, and on the very next cycle, it will reattempt the data transfer (entering the Read phase), where the ready signal is checked again.
     - **Completion of Current Word:** If the currently transmitted data word is identified as the final segment of the frame, the transmitter prepares to update its progress.
     	 These updates are essential because they determine whether more data remains for the frame. If the remaining data counter is greater than zero, the controller returns to the Data Transfer Phase to process the next data word; if the counter reaches zero, indicating that the entire frame has been transmitted, the system then transitions to the final phase.

4. **Final Phase (End):**  
   - **Purpose:**  
     To complete and clean up the current frame transmission.
   - **Operation:**  
     In this phase, the controller resets the BUSY and PROGRAM flags in the control register to signal that the frame transfer is complete. Additionally, if interrupts have been enabled via the configuration interface, an interrupt signal is issued to notify external logic of the transmission’s end. Once the finalization tasks are performed, the controller returns to the Initial Phase, ready to accept a new transmission request.
   - **Interrupt Generation:**
       - Clears the busy bit in the transmit control register.
       - Asserts the interrupt output (`interrupt_out`) if the interrupt enable flag is set. This signal notifies external logic that the current transmission is complete.

### 4.3 Data Path and Framing

The transmitter stores the complete Ethernet frame in a dual-port memory that serves as a frame buffer. The memory layout is designed so that the first few words contain the MAC addresses, followed by the frame payload data. The transmitter then accesses this memory sequentially to build the frame output for the AXI-stream interface.
Below are the Strobe generation, Memory Organization process, and two detailed flows for the transmitter framing operation—one for normal operation and another for the MAC program mode.

#### AXI Strobe generation (`axis_tstrb_out`)
This logic generates the byte strobe signal for the 32-bit transmit data word. The strobe indicates which of the four bytes in the data word are valid and should be transmitted. When padding is enabled (length < 64 bytes), strobe is made 0xF for zero data sent on AXI frame.
- **State Check:**  
  The logic only updates the strobe during the state when data is being read (the "read" phase of the transmitter).
- **Full Word Case:**  
  If the remaining transmit length (tracked by a counter) is 4 bytes or more, then a full word is being sent. In this case, the strobe is set to `4'hF` (all four bytes are valid).
- **Partial Word Case:**  
  If fewer than 4 bytes remain, the lower two bits of the length counter determine the valid bytes:
  - If the remainder is **3** (`2'd3`), the strobe is set to `4'h7` (binary 0111), indicating that the lowest three bytes are valid.
  - If the remainder is **2** (`2'd2`), the strobe is set to `4'h3` (binary 0011), indicating that the lowest two bytes are valid.
  - If the remainder is **1** (`2'd1`), the strobe is set to `4'h1` (binary 0001), indicating that only the lowest byte is valid.
  - If there is no remaining byte (default case), the strobe is set to `4'h0`.

#### Memory Organization

- **MAC Address Storage:**  
  The initial three memory word locations (addresses) are reserved for the Ethernet MAC addresses. They are programmed as follows:
  - **Address 0x0000:**  
    Contains the lower 32 bits of the destination MAC address. This covers four out of the six bytes that make up the destination address.
  - **Address 0x0004:**  
    Combines two critical pieces of data:  
    - In the lower 16 bits, it holds the remaining two bytes (upper half) of the destination MAC address.  
    - In the upper 16 bits, it stores the lower two bytes of the source MAC address.
  - **Address 0x0008:**  
    Contains the upper 32 bits of the source MAC address. These four bytes complete the 6-byte source MAC address. The source MAC address will be the same for all frames.
    
- **Payload Data Storage:**  
  - **Starting at Address 0x000C:**  
    The rest of the memory is allocated to hold the frame payload.  
  - **Organization:**  
    The payload is written as a series of 32-bit words. If the payload does not exactly align to 32-bit boundaries (i.e., the final word is incomplete), the unused bytes are defaulted to zero to ensure a complete word is stored.
    
  - **Frame Construction:**  
    The transmitted frame is constructed by first outputting the MAC addresses (which account for 12 bytes in total when combined), followed immediately by the payload data. If the overall frame length (including the MAC addresses and payload) is less than 64 bytes (the Ethernet minimum), the transmitter automatically applies padding (zeroes) at the end so that the total frame length meets the standard.

#### Transmitter Normal Frame Flow

- **Configure Frame Length and Interrupt Enable (Addresses 0x07F4 and 0x07F8):**  
   - **Frame Length Configuration (0x07F4):**  
     Before transmission begins, a configuration register is programmed with the total frame length. This length includes the header bytes (from the MAC addresses) plus the payload. Internally, this value is loaded into a counter that will track the remaining number of bytes to be sent during transmission. If the total length is less than 64 bytes—the minimum Ethernet frame size—the transmitter automatically increases the effective length to 64 bytes by adding padding.  
   - **Interrupt Enable (0x07F8):**  
     A separate register controls whether an interrupt is generated at the end of the transmission. By setting this register appropriately, you instruct the transmitter to assert an interrupt signal once the frame has been fully transmitted (including `axis_tlast_out`). This enables external logic to immediately act on the completion of a frame.

- **Configure MAC Addresses (Memory Addresses 0x0000, 0x0004, and 0x0008):**  
   - **Destination MAC Address:**  
     - **Address 0x0000:**  
       The first 32 bits are programmed with the lower portion of the destination MAC address.  
     - **Address 0x0004:**  
       This address contains the remaining 16 bits of the destination MAC address.  
   - **Source MAC Address:**  
     - **Address 0x0004 (Upper 16 bits):**  
       The same address that finishes the destination MAC is also used here to store the lower 16 bits of the source MAC address.  
     - **Address 0x0008:**  
       This address is programmed with the upper 32 bits of the source MAC address, completing the 48-bit value.  
     
   By configuring these addresses, the module ensures that the first 12 bytes of the transmitted frame correctly contain the destination and source MAC addresses, which are critical for Ethernet frame routing.

- **Program Frame Payload (Starting at Memory Address 0x000C):**  
   - **Payload Data Loading:**  
     Starting at address 0x000C, the transmitter's memory is loaded with the payload data. The payload is written as a series of 32-bit words.  
   - **Partial Word Handling:**  
     If the payload does not exactly fill a complete 32-bit word, the remaining bytes of that word are filled with zeros. This ensures that every memory read results in a valid 32-bit word and that any final word transmitted only includes the valid bytes (with the unused lanes being padded if necessary).  
     
   The organized memory layout guarantees that the frame data follows the MAC header data, and that when the frame is streamed out, it adheres to the correct sequence.

- **Start Transmission by Setting the Control Register (Address 0x07FC):**  
   - **Triggering the FSM:**  
     With all the frame parameters and payload data configured, the transmission is initiated by writing to the control register at address 0x07FC. Writing the appropriate control value (for example, 0x00000001 for setting the busy indicator) informs the transmitter that the frame can be sent out. The PROGRAM bit set is not required in normal operation.  
   - **Control Actions:**  
     At this point, the finite-state machine (FSM) governing the transmitter begins its operation. The FSM will start by reading the pre-loaded data from memory, decrementing the frame length counter as words are transmitted, and incrementing the memory pointer with each successful transfer.

- **Wait for Transmission Completion:**  
   - **Flow Monitoring:**  
     As the data is streamed out over the AXI-stream interface, the transmitter monitors a key signal:
     - If the interrupt enable register (0x07F8) was configured to generate an interrupt, the external controller waits for the interrupt signal.  
   - **Completion Verification:**  
     Once the frame is completely transmitted and either the interrupt is received or the end-of-frame (`axis_tlast_out`) signal is observed, the data transfer is confirmed to be complete. The transmitter then resets its internal state, preparing for the next transmission command.

#### Transmitter MAC Program Mode Flow

In this mode, only the MAC address information is updated while the previously stored payload remains unchanged. This is useful when only the destination MAC requires updating without reprogramming the complete frame data.

**Configure Interrupt Enable (0x07F8)**  
- **Interrupt Enable (0x07F8):**  
  - Set the register to enable interrupt generation upon MAC address update. Mandatory in this mode as there won't be any AXI data output.

**Configure MAC Addresses (Memory Addresses 0x0000, 0x0004, and 0x0008)**  
- **Update Destination MAC Address:**  
  - **Address 0x0000:** Write the new lower 32 bits of the destination MAC address.  
  - **Address 0x0004 (Lower 16 bits):** Write the new remaining 16 bits of the destination MAC address.
- **Source MAC Address Configuration:**  
  - In many scenarios, the source MAC address remains unchanged. However, if needed, the source MAC can similarly be updated at addresses 0x0004 (upper 16 bits) and 0x0008 (upper 32 bits).  

**Start Transmission by Setting the Control Register with PROGRAM Mode (Address 0x07FC)**  
- **Triggering MAC Program Mode:**  
  - Write the control value to 0x07FC with the PROGRAM and BUSY bits selected.  
  - This instructs the FSM to bypass the normal payload load procedure. Instead, it reads the updated MAC header along with the previously stored payload.
- **FSM Operations (MAC Program Mode):**  
  - The FSM quickly updates only the MAC address region and then proceeds to the END state, waiting for the Next BUSY bit to set for frame transfer.

**Wait for Transmission Completion**  
  - Similar to normal operation, enable the 0x07FC BUSY Bit[0] to start transmission( PROGRAM Bit should be zero), and the output is monitored over the AXI-stream interface.  
  - **With Interrupt Enabled:** The system waits for the interrupt signal generated after transmission.  
  - After the frame (now composed of the newly updated MAC header and the unchanged payload) is transmitted and completion is signaled, the transmitter resets its internal state, ready for subsequent operations.

### 4.4 Register Readback

The module supports readback of its internal status and configuration:
- When `cfg_wr_in` is deasserted, the module drives `cfg_data_rd_out` with status data selected based on the lower 16 bits of the configuration address:
  - **0x07F4:** Returns the transmit length.
  - **0x07F8:** Returns the interrupt enable state.
  - **0x07FC:** Returns the transmit control status.
  - For other addresses, data from the DP-RAM is returned.

## 5. Submodule: Ethernet Data Path RAM

### 5.1 Module Overview

The **ethernet_dp_ram** is a parameterized dual-port RAM used to store the transmit frame data. Key characteristics include:

- **Parameters:**  
  - **WIDTH:** The data width, set to 32 bits.
  - **ADDR_W:** The address width (10 bits in this instance), allowing for 2¹⁰ (1024) memory locations.
  
- **Port Interfaces:**  
  - **Port 0 (Configuration Side):**  
    - Accepts address, writes data, and a write enable signal.  
    - Used for writing frame data during configuration.
  - **Port 1 (Transmit Side):**  
    - Provides read access to the stored data based on the transmit pointer.

#### IO Port List

- **clk0_in**: Input, 1-bit Clock signal for DP-RAM.
- **addr0_in**: Input, ADDR_W bits. Address for configuration access.
- **data0_in**: Input, WIDTH bits. Data input for configuration writes.
- **wr0_in**: Input, 1-bit. Active HIGH Write enable for configuration port.
- **addr1_in**: Input, ADDR_W bits. Address for transmitter read access.
- **data1_in**: Input, WIDTH bits – (Unused) Data input for transmitter port.
- **wr1_in**: Input, 1-bit – Active HIGH. Write enable for the transmitter port. Hardcode to zero for read-only mode.
- **data0_out**: Output, WIDTH bits – Data output for configuration port.
- **data1_out**: Output, WIDTH bits – Data output for transmitter read access.

### 5.2 Dual-Port RAM Operation

**Write Operation (Port 0):**  
- When the configuration write enable (wr0_in) is asserted, a 32-bit data word is written into the RAM via the configuration port.  
- The memory address is provided through the configuration address input (addr0_in), ensuring word-aligned access.  
- The data is supplied on the data input (data0_in), and the write operation takes effect with a one-clock-cycle delay.  
- After this delay, the written data becomes available on the configuration data output (data0_out) for verification or readback.

**Read Operation (Port 1):**  
- The transmit engine accesses the stored frame data through the transmit read port using the address provided on addr1_in.  
- The corresponding 32-bit data word is then output via data1_out after a one-clock-cycle latency from the time the address is supplied.  
- This read latency ensures that the transmitter receives the required data on time for continuous frame streaming over the AXI-stream interface.

## 6. Timing, Constraints, and Assumptions

- **Minimum  and Maximum Frame Length:**  
  The module enforces a minimum frame size of 64 bytes and a maximum frame size of 1518 bytes (including MAC addresses). If the configured transmit length is less than 64 bytes, data padding is applied to reach the required frame length.

- **Throughput:**  
  - Data is processed in 32-bit words.  
  - The AXI-stream handshaking (using `axis_tvalid_out` and `axis_tready_in`) ensures lossless, synchronous data transfer.
  - There is no requirement for backpressure. `axis_tready_in` will always be HIGH.

- **Configuration and Control Protocols:**  
  - It is assumed that the configuration registers are updated by external control logic only when the module is idle (i.e., not in an active transmission phase).
  - The control signals (such as the busy bit and program bit in the TX control register) correctly reflect the state of the transmitter and manage state transitions.


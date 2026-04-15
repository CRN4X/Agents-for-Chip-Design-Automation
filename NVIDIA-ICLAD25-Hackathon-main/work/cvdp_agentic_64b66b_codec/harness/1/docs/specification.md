# **64b/66b Codec Specification Document**

## **1. Overview**
The 64b/66b encoding scheme is a line coding technique defined by the IEEE 802.3 standard for high-speed serial communication (e.g., 10GbE, PCIe). It addresses two primary transmission challenges:
- **Clock recovery**: Ensuring frequent transitions to maintain synchronization.
- **DC balance**: Avoiding long sequences of identical bits that might skew signal integrity.

The encoder maps 64-bit data along with optional control indicators into a 66-bit encoded format. The decoder reconstructs the original 64-bit data and control information, detecting synchronization and format errors.

## **2. Module Hierarchy**
```
top_64b66b_codec (Top-level)
├── encoder_data_64b66b (Data path encoder)
├── encoder_control_64b66b (Control path encoder)
└── decoder_data_control_64b66b (Data and control path decoder)
```

## **3. Top-Level Module**

### **3.1 top_64b66b_codec**
The system integrator instantiates and connects all submodules. Routes signals based on control inputs and handles data flow between encoder/decoder paths.

#### **I/O Port List**
| Port                  | Direction | Width | Description                      |
|-----------------------|-----------|-------|----------------------------------|
| `clk_in`              | input     | 1     | System clock (rising-edge)       |
| `rst_in`              | input     | 1     | Active-high synchronous reset    |
| `enc_data_in`         | input     | 64    | Data input for encoding          |
| `enc_control_in`      | input     | 8     | Control input for encoding       |
| `enc_data_out`        | output    | 66    | Encoded output                   |
| `dec_data_valid_in`   | input     | 1     | Decoder input valid signal       |
| `dec_data_in`         | input     | 66    | Encoded input for decoding       |
| `dec_data_out`        | output    | 64    | Decoded data output              |
| `dec_control_out`     | output    | 8     | Decoded control output           |
| `dec_sync_error`      | output    | 1     | Sync header error flag           |
| `dec_error_out`       | output    | 1     | Comprehensive error indicator    |

## **4. Submodules**

### **4.1 encoder_data_64b66b**
Handles pure data path encoding with "01" sync headers.

#### **Key Features**
- Processes 64-bit data words
- Generates 2'b01 sync header
- Zero-latency data pass-through
- No type field insertion

#### **I/O Port List**
| Port                  | Direction | Width | Description                      |
|-----------------------|-----------|-------|----------------------------------|
| `clk_in`              | input     | 1     | System clock                     |
| `rst_in`              | input     | 1     | Active-high reset                |
| `encoder_data_in`     | input     | 64    | Input data word                  |
| `encoder_control_in`  | input     | 8     | Control mask                     |
| `encoder_data_out`    | output    | 66    | Encoded output (01 + data)       |

### **4.2 encoder_control_64b66b**
Encodes control sequences based on both the control flags and matching data patterns.

- Adds sync header `10`
- Appends an **8-bit type field** to classify the control pattern
- Encodes remaining 56 bits based on predefined mappings
- Detects and encodes special sequences such as:
  - Idle sequences
  - Start/End of packet delimiters
  - Custom application codes

Control encoding ensures:
- Consistent mapping for control events
- Valid type field generation
- Zero padding or data substitution to enforce format

#### **I/O Port List**
| Port                  | Direction | Width | Description                      |
|-----------------------|-----------|-------|----------------------------------|
| `clk_in`              | input     | 1     | System clock                     |
| `rst_in`              | input     | 1     | Active-high reset                |
| `encoder_data_in`     | input     | 64    | Input data/control word          |
| `encoder_control_in`  | input     | 8     | Control mask                     |
| `encoder_data_out`    | output    | 66    | Encoded output (10 + type + data)|

#### **Design Specification**
The encoder_control_64b66b converts 64-bit data words and 8-bit control words into 66-bit encoded output with three operational modes:

1. **Control-Only Mode**:  
   - Activated when `encoder_control_in` = 8'hFF
   - Sync word set to 2'b10
   - Full control character replacement

2. **Mixed Mode**:  
   - Activated for 0 < `encoder_control_in` < 8'hFF
   - Sync word set to 2'b10
   - Combines data bytes and control characters

#### **Control Character Encoding**
| Control Character | Hex Value | Encoded Value | Usage                |
|-------------------|-----------|---------------|----------------------|
| Idle (/I/)        | 0x07      | 7'h00         | Link synchronization |
| Start (/S/)       | 0xFB      | 4'b0000       | Packet delineation   |
| Terminate (/T/)   | 0xFD      | 4'b0000       | End-of-packet        |
| Error (/E/)       | 0xFE      | 7'h1E         | Error propagation    |
| Ordered Set (/Q/) | 0x9C      | 4'b1111       | Configuration        |


#### **Valid Control Input Combinations with Type Field Lookup Table**

| **Data Input [63:0]**            | **Control Input**| **Output [65:64]**| **Output [63:56]**| **Output [55:0]**                       |
|----------------------------------|------------------|-------------------|-------------------|-----------------------------------------|
| `I7, I6, I5, I4, I3, I2, I1, I0` | `8'b11111111`    | `2'b10`           | `0x1e`            | `C7, C6, C5, C4, C3, C2, C1, C0`        |
| `E7, E6, E5, E4, E3, E2, E1, E0` | `8'b11111111`    | `2'b10`           | `0x1e`            | `C7, C6, C5, C4, C3, C2, C1, C0`        |
| `D7, D6, D5, S4, I3, I2, I1, I0` | `8'b00011111`    | `2'b10`           | `0x33`            | `D7, D6, D5, 4'b0000, C3, C2, C1, C0`   |
| `D7, D6, D5, D4, D3, D2, D1, S0` | `8'b00000001`    | `2'b10`           | `0x78`            | `D7, D6, D5, D4, D3, D2, D1, D0`        |
| `I7, I6, I5, I4, I3, I2, I1, T0` | `8'b11111110`    | `2'b10`           | `0x87`            | `C7, C6, C5, C4, C3, C2, C1, 7'b0000000`|
| `I7, I6, I5, I4, I3, I2, T1, D0` | `8'b11111110`    | `2'b10`           | `0x99`            | `C7, C6, C5, C4, C3, C2, 6'b000000, D0` |
| `I7, I6, I5, I4, I3, T2, D1, D0` | `8'b11111100`    | `2'b10`           | `0xaa`            | `C7, C6, C5, C4, C3, 5'b00000, D1, D0`  |
| `I7, I6, I5, I4, T3, D2, D1, D0` | `8'b11111000`    | `2'b10`           | `0xb4`            | `C7, C6, C5, C4, 4'b0000, D2, D1, D0`   |
| `I7, I6, I5, T4, D3, D2, D1, D0` | `8'b11110000`    | `2'b10`           | `0xcc`            | `C7, C6, C5, 3'b000, D3, D2, D1, D0`    |
| `I7, I6, T5, D4, D3, D2, D1, D0` | `8'b11100000`    | `2'b10`           | `0xd2`            | `C7, C6, 2'b00, D4, D3, D2, D1, D0`     |
| `I7, T6, D5, D4, D3, D2, D1, D0` | `8'b11000000`    | `2'b10`           | `0xe1`            | `C7, 1'b0, D5, D4, D3, D2, D1, D0`      |
| `T7, D6, D5, D4, D3, D2, D1, D0` | `8'b10000000`    | `2'b10`           | `0xff`            | `D6, D5, D4, D3, D2, D1, D0`            |
| `D7, D6, D5, Q4, I3, I2, I1, I0` | `8'b00011111`    | `2'b10`           | `0x2d`            | `D7, D6, D5, 4'b1111, C3, C2, C1, C0`   |
| `I7, I6, I5, I4, D3, D2, D1, Q0` | `8'b11110001`    | `2'b10`           | `0x4b`            | `C7, C6, C5, C4, D3, D2, D1, 4'b1111`   |
| `D7, D6, D5, Q4, D3, D2, D1, Q0` | `8'b00010001`    | `2'b10`           | `0x55`            | `D7, D6, D5, 8'b11111111, D3, D2, D1`   |
| `D7, D6, D5, S4, D3, D2, D1, Q0` | `8'b00010001`    | `2'b10`           | `0x66`            | `D7, D6, D5, 8'b00001111, D3, D2, D1`   |

### **4.3 decoder_data_control_64b66b**
Combined decoder handling both data and control paths. The decoder handles the full 66-bit word and interprets it based on the sync header.

- **Sync header `01`**: Interpreted as raw data
- **Sync header `10`**: Parsed using the type field to reconstruct original data and control meaning

#### Functionality:
- Extracts and checks sync headers
- Maps type fields back to original control flags
- Reconstructs data based on encoding format
- Detects invalid sync headers and unknown control types
- Performs data validation for encoded formats

#### Error Detection:
- **Sync Error**: Raised for invalid sync headers (neither `01` nor `10`)
- **Format Error**: Raised if control types do not match expected format

#### **I/O Port List**
| Port                      | Direction | Width | Description                      |
|---------------------------|-----------|-------|----------------------------------|
| `clk_in`                  | input     | 1     | System clock                     |
| `rst_in`                  | input     | 1     | Active-high reset                |
| `decoder_data_valid_in`   | input     | 1     | Input data valid                 |
| `decoder_data_in`         | input     | 66    | Encoded input                    |
| `decoder_data_out`        | output    | 64    | Decoded data                     |
| `decoder_control_out`     | output    | 8     | Decoded control mask             |
| `sync_error`              | output    | 1     | Header error flag                |
| `decoder_error_out`       | output    | 1     | Composite error indicator        |


#### **Control Character Mapping**

| Character | Hex | Usage                     |
|-----------|-----|---------------------------|
| /I/       | 0x07| Idle sequence             |
| /S/       | 0xFB| Start of packet           |
| /T/       | 0xFD| End of packet             |
| /E/       | 0xFE| Error indication          |
| /Q/       | 0x9C| Ordered set               |

#### **Decoding Table**
| **Type Field** | **decoder_control_out**  | **decoder_data_out**              |
|----------------|--------------------------|-----------------------------------|
| `0x1E`         | `8'b11111111`            | `{E7, E6, E5, E4, E3, E2, E1, E0}`|
| `0x33`         | `8'b00011111`            | `{D6, D5, D4, S4, I3, I2, I1, I0}`|
| `0x78`         | `8'b00000001`            | `{D6, D5, D4, D3, D2, D1, D0, S0}`|
| `0x87`         | `8'b11111110`            | `{I7, I6, I5, I4, I3, I2, I1, T0}`|
| `0x99`         | `8'b11111110`            | `{I7, I6, I5, I4, I3, I2, T1, D0}`|
| `0xAA`         | `8'b11111100`            | `{I7, I6, I5, I4, I3, T2, D1, D0}`|
| `0xB4`         | `8'b11111000`            | `{I7, I6, I5, I4, T3, D2, D1, D0}`|
| `0xCC`         | `8'b11110000`            | `{I7, I6, I5, T4, D3, D2, D1, D0}`|
| `0xD2`         | `8'b11100000`            | `{I7, I6, T5, D4, D3, D2, D1, D0}`|
| `0xE1`         | `8'b11000000`            | `{I7, T6, D5, D4, D3, D2, D1, D0}`|
| `0xFF`         | `8'b10000000`            | `{T7, D6, D5, D4, D3, D2, D1, D0}`|
| `0x2D`         | `8'b00011111`            | `{D6, D5, D4, Q4, I3, I2, I1, I0}`|
| `0x4B`         | `8'b11110001`            | `{I7, I6, I5, I4, D2, D1, D0, Q0}`|
| `0x55`         | `8'b00010001`            | `{D6, D5, D4, Q4, D2, D1, D0, Q0}`|
| `0x66`         | `8'b00010001`            | `{D6, D5, D4, S4, D2, D1, D0, Q0}`|

- **Explanation**:
     - `Dx`: Represents data bits from the input.
     - `Ix`: Represents idle control characters (`/I/`).
     - `Sx`: Represents start-of-frame control characters (`/S/`).
     - `Tx`: Represents end-of-frame control characters (`/T/`).
     - `Ex`: Represents error control characters (`/E/`).
     - `Qx`: Represents ordered-set control characters (`/Q/`).

#### **Error Signal Implementation**:
   - The module generates two error signals:
     1. **`sync_error`**:
        - Asserted HIGH when the sync header is invalid (neither `2'b01` nor `2'b10`).
        - This indicates a synchronization error, meaning the input data is not properly aligned or formatted.
     2. **`decoder_error_out`**:
        - Asserted HIGH when either:
          - The type field is invalid (not in the predefined list of valid type fields).
          - The control data (`data_in`) does not match the expected pattern for the given type field.
        - This indicates a decoding error, meaning the input data cannot be properly decoded.
        - The `decoder_error_out` signal is generated by combining the above two conditions.

## **5. Latency**
| Module                  | Latency |
|-------------------------|---------|
| encoder_data_64b66b     | 1 cycle |
| encoder_control_64b66b  | 1 cycle |
| decoder_data_control_64b66b | 1 cycle |

## **6. Operational Notes**
1. **Clock Domain**:
   - All modules synchronous to clk_in
   - No cross-clock domain handling

2. **Reset Behavior**:
   - Clears all registers
   - Outputs forced to zero
   - Error flags cleared

3. **Performance Tradeoffs**:
   - Fixed 1-cycle latency
   - Balanced pipeline design
   - Critical path optimization
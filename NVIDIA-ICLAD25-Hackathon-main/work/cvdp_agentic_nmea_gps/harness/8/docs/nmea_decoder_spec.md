# **NMEA Decoder Specification**

## **Overview**
The `nmea_decoder` module is designed to parse NMEA 0183 sentences received serially and extract relevant data fields from `GPRMC` sentences. The module receives an ASCII-encoded NMEA sentence, processes the character stream, identifies delimiters, and extracts the first data field following the sentence type. The extracted data is provided as a 16-bit output along with a valid signal.

---

## **NMEA Sentence Structure**
NMEA sentences follow a standard ASCII format with fields separated by commas:

`$GPRMC,time,status,latitude,N/S,longitude,E/W,speed,course,date,magvar,E/W*checksum\r\n`
- Each sentence starts with a `$` character.
- Fields are separated by commas (`,`).
- Sentences end with a carriage return (`\r`).
- The `GPRMC` sentence contains important navigation data.

The `nmea_decoder` extracts **the first data field** following the `GPRMC` sentence identifier.

---

## **Module Interface**

### Inputs
- **`clk`** (1 bit): System clock.
- **`reset`** (1 bit): Active-high synchronous reset.
- **`serial_in`** (8 bits): Incoming ASCII character.
- **`serial_valid`** (1 bit): Indicates valid character input.

### Outputs
- **`data_out`** (16 bits): Extracted data field from the NMEA sentence.
- **`data_valid`** (1 bit): Indicates valid data in `data_out`.

---

## **Finite State Machine (FSM)**
The module operates using a three-state FSM:

### **State Definitions:**
- **STATE_IDLE**
  - Waits for the start of an NMEA sentence (`$` character).
  - Transitions to `STATE_PARSE` when the start character is detected.

- **STATE_PARSE**
  - Buffers characters and tracks comma positions to identify field locations.
  - Transitions to `STATE_OUTPUT` upon detecting the sentence termination (`\r`).

- **STATE_OUTPUT**
  - Extracts the first data field after `GPRMC`.
  - Outputs the extracted field as a 16-bit value (`data_out`).
  - Asserts `data_valid` for one clock cycle.
  - Returns to `STATE_IDLE`.

---

## **Buffering and Parsing Logic**
- The module maintains an **80-character buffer** to store incoming NMEA sentences.
- It tracks **comma delimiters** to locate specific fields.
- After identifying the `GPRMC` sentence, it extracts the **first data field** following the identifier.


## **Latency Considerations**
1. **Character Processing Phase:**
   - The module processes one character per clock cycle.
   - Parsing continues until a carriage return (`\r`) is detected.

2. **Data Extraction Phase:**
   - The first data field is located and stored in `data_out`.
   - `data_valid` is asserted for one cycle.

3. **FSM Transition Timing:**
   - Typical latency from `$` detection to output is determined by the sentence length and field position.
   

## **Error Handling**
- If the sentence buffer exceeds 80 characters, the module resets to `STATE_IDLE`.
- Only `GPRMC` sentences are processed; other sentence types are ignored.
- If an incomplete or malformed sentence is received, it is discarded.


## **Design Constraints**
- Supports an **80-character maximum buffer size**.
- Only extracts **GPRMC sentences**.
- Operates in a **clocked environment** with a synchronous reset.


## **Deliverables**
- The complete **RTL implementation** of `nmea_decoder.v`.
- Testbench validation for different NMEA sentence formats.
- The final extracted data output for `GPRMC` sentence fields.


This specification defines the behavior, interface, and implementation details required for the `nmea_decoder` module.
Design a **traffic controller finite state machine (FSM)** for a simple intersection in System Verilog names `traffic_controller_fsm`. Based on sensor inputs and timing signals, the FSM manages the traffic lights for both a main road and a side road. Your goal is to implement this FSM in System Verilog, adhering to the following specifications.

#### Inputs and Outputs

| Signal                        | Direction | Bit Width | Active Level | Description                                                                                |
|-------------------------------|-----------|-----------|--------------|--------------------------------------------------------------------------------------------|
| **`i_clk`**                   | Input     | 1         | —            | System clock signal, with FSM transitions occurring on the rising edge.                    |
| **`i_rst_b`**                 | Input     | 1         | Active-low   | Asynchronous reset signal. When asserted (`0`), FSM resets to its initial state.           |
| **`i_vehicle_sensor_input`**  | Input     | 1         | Active-high  | Detects vehicle presence on the side road. High (`1`) when a vehicle is detected.          |
| **`i_short_timer`**           | Input     | 1         | Active-high  | Indicates the expiration of the short timer. High (`1`) when the short timer expires.      |
| **`i_long_timer`**            | Input     | 1         | Active-high  | Indicates the expiration of the long timer. High (`1`) when the long timer expires.        |
| **`o_short_trigger`**         | Output    | 1         | Active-high  | Initiates the short timer. Set to high (`1`) to start the short timer.                     |
| **`o_long_trigger`**          | Output    | 1         | Active-high  | Initiates the long timer. Set to high (`1`) to start the long timer.                       |
| **`o_main[2:0]`**             | Output    | 3         | —            | Controls main road traffic lights: Red (`3'b100`), Yellow (`3'b010`), Green (`3'b001`).    |
| **`o_side[2:0]`**             | Output    | 3         | —            | Controls side road traffic lights: Red (`3'b100`), Yellow (`3'b010`), Green (`3'b001`).    |

#### FSM Output Table

| State     | Description                           | `o_main`          | `o_side`          | `o_short_trigger`  | `o_long_trigger`  |
|-----------|---------------------------------------|-------------------|-------------------|--------------------|-------------------|
| **S1**    | Main road green, side road red        | `3'b001` (Green)  | `3'b100` (Red)    | 0                  | 1                 |
| **S2**    | Main road yellow, side road red       | `3'b010` (Yellow) | `3'b100` (Red)    | 1                  | 0                 |
| **S3**    | Main road red, side road green        | `3'b100` (Red)    | `3'b001` (Green)  | 0                  | 1                 |
| **S4**    | Main road red, side road yellow       | `3'b100` (Red)    | `3'b010` (Yellow) | 1                  | 0                 |

#### FSM Transition Logic
- **S1 → S2**: Transition when a vehicle is detected (`i_vehicle_sensor_input = 1`) and the long timer expires (`i_long_timer = 1`).
- **S2 → S3**: Transition upon short timer expiration (`i_short_timer = 1`).
- **S3 → S4**: Transition when either vehicle is detected (`i_vehicle_sensor_input = 1`) or the long timer expires (`i_long_timer = 1`).
- **S4 → S1**: Transition upon short timer expiration (`i_short_timer = 1`).

#### Requirements
1. **Reset Behavior**: When the reset signal is active (`i_rst_b = 0`), the FSM should reset to **State S1** with the following initial values:
   - **`o_main`** set to `3'b000` (main road lights off).
   - **`o_side`** set to `3'b000` (side road lights off).
   - **`o_long_trigger`** set to `1'b0` (long timer trigger reset).
   - **`o_short_trigger`** set to `1'b0` (short timer trigger reset).
2. **Clocked Transitions**: The FSM should transition between states on the rising edge of the clock (`i_clk`).
3. **Synchronized Outputs**: Ensure the traffic light outputs (`o_main` and `o_side`) and the timer triggers (`o_long_trigger`, `o_short_trigger`) are properly synchronized with state transitions.

#### Additional Notes
- Use local parameters for state encoding.
- Implement a clean and efficient next-state logic and state-assignment logic based on the provided state descriptions.
- Ensure the FSM behaves as expected in both typical and edge cases, including handling the reset signal and timer expirations correctly.
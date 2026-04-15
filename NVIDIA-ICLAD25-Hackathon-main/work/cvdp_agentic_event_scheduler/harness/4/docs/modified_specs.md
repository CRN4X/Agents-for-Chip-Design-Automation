# Modified Event Scheduler Module Specification

This module implements a programmable event scheduler for real-time systems with enhanced capabilities. In addition to the original functionality (dynamic event addition and cancellation, time tracking, and priority-based triggering), the modified design supports:

## Event Modification/Rescheduling
- **Functionality:** Allows an existing event to be updated with a new timestamp and priority.
- **Operation:** When the `modify_event` control signal is asserted, the scheduler updates the event’s scheduled time and its priority using `new_timestamp` and `new_priority` respectively.

## Recurring Events
- **Functionality:** Supports periodic events by automatically rescheduling an event when triggered if it is marked as recurring.
- **Operation:** When an event with the recurring flag is triggered, its timestamp is updated by adding the `recurring_interval`, allowing it to trigger again.

## Event Logging
- **Functionality:** Provides logging outputs that capture the time and event ID whenever an event is triggered.
- **Operation:** Each time an event is triggered, the scheduler logs the system time (`log_event_time`) and the event identifier (`log_event_id`) for diagnostic and debugging purposes.

## Parameterization
- **MAX_EVENTS:** 16  
  The scheduler supports 16 distinct events, indexed 0 to 15.
- **TIMESTAMP_WIDTH:** 16 bits  
  Each event timestamp is 16 bits wide, representing time in nanoseconds.
- **PRIORITY_WIDTH:** 4 bits  
  Event priorities are represented with 4 bits, used to resolve conflicts among due events.
- **TIME_INCREMENT:** 10 ns  
  The internal system time is incremented by 10 ns every clock cycle.

## Additional Parameters
- **Recurring Event Flag:**  
  A binary signal indicating if an event is periodic.
- **Recurring Interval:**  
  A 16-bit value that specifies the interval (in ns) after which a recurring event should be rescheduled.

## Interfaces

### Clock and Reset
- **clk:**  
  Posedge Clock signal driving synchronous operations.
- **reset:**  
  Asynchronous Active-high reset that initializes the system and clears all event-related data.

### Control Signals
- **add_event:**  
  When asserted ACTIVE HIGH the addition of a new event.
- **cancel_event:**  
  When asserted ACTIVE HIGH , makes the DUT perform cancellation of an existing event.
- **modify_event:**  
  When asserted ACTIVE HIGH, instructs the scheduler to modify (reschedule and/or change the priority of) an existing event.

### Event Input Data
- **event_id (4 bits, [3:0]):**  
  Identifier for the event (0 to 15). Used for addition, cancellation, and modification.
- **timestamp (16 bits, [15:0]):**  
  The scheduled time at which the event should be triggered when added.
- **priority_in (4 bits, [3:0]):**  
  The priority for the event when added; higher values indicate higher priority.
- **new_timestamp (16 bits, [15:0]):**  
  The updated timestamp for an event when `modify_event` is asserted.
- **new_priority (4 bits, [3:0]):**  
  The updated priority for an event when `modify_event` is asserted.
- **recurring_event (1-bit):**  
  A flag that, when set ACTIVE HIGH, indicates that the event should automatically reschedule after being triggered.
- **recurring_interval (16 bits, [15:0]):**  
  Specifies the interval (in ns) by which to reschedule a recurring event after each trigger.

### Event Output Data
- **event_triggered (1-bit):**  
  A one-clock-cycle pulse indicating that an event has been triggered.
- **triggered_event_id (4 bits, [3:0]):**  
  The identifier of the event that was triggered.
- **error (1-bit):**  
  Signals an error when an invalid operation is attempted (e.g., adding an event to an already active slot, or modifying/canceling a non-existent event).
- **current_time (16 bits, [15:0]):**  
  The internal system time, which is incremented by 10 ns every clock cycle.
- **log_event_time (16 bits, [15:0]):**  
  Captures the system time at which an event was triggered. Useful for logging and debugging.
- **log_event_id (4 bits, [3:0]):**  
  Records the event ID that was triggered at the time logged.

## Detailed Functionality

### 1. Event Storage and Temporary Updates
- **Primary Storage Arrays:**  
  - `event_timestamps`: Holds the scheduled time for each event.  
  - `event_priorities`: Holds the priority value for each event.  
  - `event_valid`: Flags indicating if an event slot is active.
- **Recurring Event Storage:**  
  - `recurring_flags`: Indicates which events are recurring.  
  - `recurring_intervals`: Holds the rescheduling interval for recurring events.
- **Temporary Arrays and Atomic Update:**  
  Temporary copies (e.g., `tmp_event_timestamps`, `tmp_event_priorities`, `tmp_event_valid`, `tmp_recurring_flags`, and `tmp_recurring_intervals`) are used to perform all updates atomically within a clock cycle. The current time is updated to `tmp_current_time = current_time + 10` before evaluating event conditions.

### 2. Time Management
- **Time Increment:**  
  On every positive clock edge (outside reset), the module increments `current_time` by 10 ns. The new value is temporarily stored in `tmp_current_time` and then committed at the end of the cycle.

### 3. Event Addition, Modification, and Cancellation
- **Event Addition:**  
  When `add_event` is asserted, the scheduler checks if the event slot (`event_id`) is already active:
  - **Not Active:**  
    The event’s timestamp and priority are stored, and the slot is marked valid. If the event is recurring, the recurring flag and interval are saved.
  - **Already Active:**  
    The `error` output is asserted to indicate a duplicate event addition.
- **Event Modification:**  
  When `modify_event` is asserted, the scheduler verifies that the event is active:
  - **Active:**  
    It updates the event’s timestamp and priority using `new_timestamp` and `new_priority`. Recurring parameters are also updated.
  - **Not Active:**  
    An error is signaled.
- **Event Cancellation:**  
  When `cancel_event` is asserted, the scheduler clears the valid flag for the specified event if it exists; otherwise, an error is raised.

### 4. Event Selection, Triggering, and Logging
- **Event Eligibility:**  
  The scheduler scans through all event slots (via the temporary arrays) to determine which events are due (i.e., `tmp_event_timestamps[j] <= tmp_current_time`).
- **Priority-Based Selection:**  
  Among the eligible events, the one with the highest priority (largest value in `tmp_event_priorities`) is selected as the `chosen_event`.
- **Triggering:**  
  If an eligible event is found, the module:
  - Asserts the one-cycle `event_triggered` pulse.
  - Sets `triggered_event_id` to the selected event's ID.
  - Logs the trigger time (`log_event_time`) and event ID (`log_event_id`).
- **Recurring Events:**  
  If the event is marked as recurring (via `tmp_recurring_flags`), its timestamp is updated by adding the recurring interval, allowing the event to trigger again later. Otherwise, the event is deactivated (its valid flag is cleared).
- **No Eligible Event:**  
  If no event is eligible, `event_triggered` remains low.

### 5. State Commit
- **Commit Operation:**  
  At the end of each clock cycle, the temporary state—including current time and all event-related arrays—is written back to the corresponding permanent registers. This ensures that all operations are synchronized.

---

## Testbench Requirements

**File:** `tb_sobel_edge_detection.sv`

The provided testbench applies 10 test scenarios to fully exercise the design:

1. **Reset Behavior:**  
   - Applies a reset, then verifies that all internal signals initialize correctly.

2. **Single Pixel Pulse:**  
   - Drives a single pixel value (`din = 100`) to check basic pipeline activation.

3. **One Line Data Feed (640 Pixels):**  
   - Simulates a continuous line of pixel data to exercise window formation over an entire row.

4. **Pixel Count Trigger (1920 Pixels):**  
   - Ensures that the total pixel count reaches the threshold required to trigger the FIFO output and read mode.

5. **Intermittent Pixel Data Feed:**  
   - Randomly toggles `in_valid` to mimic noncontinuous image data.

6. **Constant Maximum Pixel Data Feed:**  
   - Provides a stream of 255 to test how the filter responds to maximum input, typically producing a consistent edge output.

7. **FIFO Backpressure Simulation:**  
   - Forces backpressure by disabling `in_ready`, then re-enables it to observe FIFO behavior.

8. **Extended Random Pixel Data Feed:**  
   - Feeds a long sequence of randomized pixels to verify robustness over prolonged operation.

9. **FIFO Preload and Monitor:**  
   - Preloads the FIFO by disabling reads while feeding pixels, then re-enables reads to ensure data is correctly buffered and output.

10. **Sudden Burst of Pixel Data:**  
    - Subjects the design to a burst of pixel data to test system response under stress conditions.

For each test scenario, the testbench monitors key signals (`data_ready`, `last_signal`, `out_valid`, `dout`, `interrupt_out`) to validate correct functional behavior across various operating conditions.

---

## Summary
The modified event scheduler maintains core functionalities such as dynamic event scheduling and priority-based triggering, while now incorporating enhanced features including event modification/rescheduling, recurring events, and comprehensive event logging. This design ensures a robust, flexible, and fully parameterized solution suitable for real-time systems where precise timing and error handling are critical. Robust error handling mechanisms signal improper operations such as duplicate additions or invalid modifications/cancellations. Overall, the advanced architecture and the detailed testbench requirements together provide a comprehensive framework for verifying correct operation under a wide range of conditions.
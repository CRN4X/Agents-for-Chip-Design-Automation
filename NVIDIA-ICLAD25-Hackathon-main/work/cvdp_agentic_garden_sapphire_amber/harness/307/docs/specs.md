# Event Scheduler Module Description

This module implements a programmable event scheduler for a real-time system. The scheduler supports up to 16 events, with each event defined by a timestamp and a priority. It continuously tracks an internal system time and triggers events when their scheduled time is reached. When multiple events are eligible, it selects the one with the highest priority. The design supports dynamic addition and cancellation of events, along with error signaling for invalid operations.

---

## Parameterization

- **MAX_EVENTS:** Fixed number of events supported – 16  
- **TIMESTAMP_WIDTH:** Bit-width of the event timestamp – 16 bits  
- **PRIORITY_WIDTH:** Bit-width of the event priority – 4 bits  
- **TIME_INCREMENT:** Increment applied to `current_time` every clock cycle – 10 ns

These parameters define the fixed storage capacity and timing resolution of the scheduler.

---

## Interfaces

### Clock and Reset

- **clk:** Clock signal for synchronous operations.
- **reset:** Active-high reset signal that initializes the system and clears all event data.

### Control Signals

- **add_event:** When asserted, instructs the scheduler to add a new event.
- **cancel_event:** When asserted, instructs the scheduler to cancel an existing event.

### Event Input Data

- **event_id** (4 bits): Identifier for the event (ranging from 0 to 15).
- **timestamp** (16 bits): The scheduled trigger time (in ns) for the event.
- **priority_in** (4 bits): Priority of the event; used for resolving conflicts when multiple events are eligible.

### Event Output Data

- **event_triggered:** A one-cycle pulse that indicates an event has been triggered.
- **triggered_event_id** (4 bits): Identifier of the event that was triggered.
- **error:** Signals an error when attempting invalid operations (e.g., adding an already active event or cancelling a non-existent event).
- **current_time** (16 bits): The current system time, which is incremented by 10 ns every clock cycle.

---

## Detailed Functionality

### 1. Event Storage and Temporary State Management

- **Event Arrays:**  
  The scheduler maintains three main arrays:
  - `event_timestamps`: Stores the scheduled timestamps for each event.
  - `event_priorities`: Stores the priority for each event.
  - `event_valid`: A flag array indicating if a particular event slot is active.
  
- **Temporary Arrays:**  
  To ensure atomic updates within a clock cycle, temporary copies of the event arrays (`tmp_event_timestamps`, `tmp_event_priorities`, and `tmp_event_valid`) are created. A temporary variable, `tmp_current_time`, holds the updated time.

### 2. Time Management

- **Incrementing Time:**  
  On each clock cycle (outside of reset), `current_time` is incremented by a fixed value (10 ns) and stored in `tmp_current_time`. This updated time is later committed back to `current_time`.

### 3. Event Addition and Cancellation

- **Event Addition:**  
  When `add_event` is asserted:
  - The scheduler checks if an event with the given `event_id` is already active.
  - If the slot is free, the event’s `timestamp` and `priority_in` are stored in the temporary arrays and marked valid.
  - If the slot is already occupied, the module sets the `error` signal.

- **Event Cancellation:**  
  When `cancel_event` is asserted:
  - The scheduler verifies if the event corresponding to `event_id` is active.
  - If active, the valid flag is cleared in the temporary state.
  - If not, an error is signaled.

### 4. Event Selection and Triggering

- **Selection Mechanism:**  
  The module scans through the temporary event arrays to find eligible events—those with a timestamp less than or equal to the updated `tmp_current_time`.  
  - If multiple eligible events exist, the one with the highest priority is chosen.

- **Triggering:**  
  If an eligible event is found:
  - The `event_triggered` signal is asserted for one clock cycle.
  - The `triggered_event_id` output is set to the chosen event.
  - The valid flag for that event is cleared in the temporary arrays to prevent it from being triggered again.

### 5. State Commit

- **Commit Process:**  
  After processing additions, cancellations, and event selection:
  - The temporary time and event arrays are written back to the main registers (`current_time`, `event_timestamps`, `event_priorities`, and `event_valid`), ensuring that all updates are synchronized at the end of the clock cycle.

---

## Summary

- **Architecture:**  
  The event scheduler is designed to manage a fixed number of events (16) using dedicated storage arrays for timestamps, priorities, and validity flags. Temporary arrays ensure that operations are performed atomically within each clock cycle.

- **Time and Priority Management:**  
  The system increments an internal clock (`current_time`) by 10 ns every cycle. It triggers events when the scheduled timestamp is reached, and when multiple events are eligible, it resolves conflicts by selecting the one with the highest priority.

- **Dynamic Handling:**  
  The scheduler supports dynamic event addition and cancellation. It also provides error signaling for invalid operations, making it robust for real-time scheduling applications.

This analysis provides a comprehensive overview of the architecture and functionality of the event scheduler module, highlighting its suitability for applications requiring precise and dynamic event management in real-time systems.

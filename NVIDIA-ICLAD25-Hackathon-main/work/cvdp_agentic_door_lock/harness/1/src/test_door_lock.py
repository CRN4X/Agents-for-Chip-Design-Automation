import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math
import random


# Function to initialize DUT inputs to 0
async def dut_init(dut):
  """
  Initialize all input signals of the DUT to 0.
  
  Args:
    dut: The Design Under Test.
  """
  for signal in dut:
    if signal._type == "GPI_NET":  # Only reset input signals (GPI_NET)
      signal.value = 0

async def reset_dut(dut, duration_ns=10):
    """
    Perform a synchronous reset on the Design Under Test (DUT).

    - Sets the reset signal high for the specified duration.
    - Ensures all output signals are zero during the reset.
    - Deactivates the reset signal and stabilizes the DUT.

    Args:
        dut: The Design Under Test (DUT).
        duration_ns: The time duration in nanoseconds for which the reset signal will be held high.
    """
    dut.srst.value = 1  # Activate reset (set to high)
    await Timer(duration_ns, units="ns")  # Hold reset high for the specified duration
    await Timer(1, units="ns")

    # Verify that outputs are zero during reset
    assert dut.door_unlock.value == 0, f"[ERROR] door_unlock is not zero during reset: {dut.door_unlock.value}"
    assert dut.lockout.value == 0, f"[ERROR] lockout is not zero during reset: {dut.lockout.value}"

    dut.srst.value = 0  # Deactivate reset (set to low)
    await Timer(duration_ns, units='ns')  # Wait for the reset to stabilize
    dut.srst._log.debug("Reset complete")

class DoorLockChecker:
  """Checker that computes expected behavior based on inputs and FSM rules."""
  def __init__(self, default_password, password_length, max_trials):
    self.stored_password = default_password
    self.password_length = password_length
    self.max_trials = max_trials
    self.entered_password = []
    self.fail_count = 0
    self.locked_out = False
    self.door_unlock = False

  def reset(self):
    """Resets internal state"""
    self.entered_password = []
    self.fail_count = 0
    self.locked_out = False
    self.door_unlock = False
    self.stored_password = self.default_password

  def process_input(self, key_input, confirm, admin_override, admin_set_mode, new_password, new_password_valid):
    """Computes expected values dynamically based on FSM transitions."""
    
    if admin_override and admin_set_mode == 0:  
      self.door_unlock = True
      self.fail_count = 0
      self.locked_out = False
      return

    if self.locked_out:
      if admin_override:
        self.locked_out = False  # Reset by admin
        self.fail_count = 0
      return

    if admin_set_mode and admin_override:
      if new_password_valid:
        self.stored_password = new_password
      return

    if key_input is not None:
      if len(self.entered_password) < self.password_length:
        self.entered_password.append(key_input)

    if confirm:
        if len(self.entered_password) == self.password_length:
            if self.entered_password == self.stored_password:
                self.door_unlock = True
                self.fail_count = 0
            else:
                self.door_unlock = False
                self.fail_count += 1
                if self.fail_count >= self.max_trials:
                    self.locked_out = True
        else:
            # Early confirm: treat as failure
            self.door_unlock = False
            self.fail_count += 1
            if self.fail_count >= self.max_trials:
                self.locked_out = True
        self.entered_password = []  # Always clear after confirm


  def get_expected_outputs(self):
    """Returns expected door unlock and lockout signals."""
    return self.door_unlock, self.locked_out

def assert_outputs(checker, dut):
  """Helper function to validate expected outputs"""
  expected_unlock, expected_lockout = checker.get_expected_outputs()
  assert dut.door_unlock.value == expected_unlock, f"Expected door_unlock={expected_unlock}, got {dut.door_unlock.value}"
  assert dut.lockout.value == expected_lockout, f"Expected lockout={expected_lockout}, got {dut.lockout.value}"

async def enter_password(checker, dut, password):
  """Enters a password sequence"""
  for digit in password:
    dut.key_input.value = digit
    dut.key_valid.value = 1
    await RisingEdge(dut.clk)
    dut.key_valid.value = 0
    await RisingEdge(dut.clk)
    checker.process_input(key_input=digit, confirm=False, admin_override=False, admin_set_mode=False, new_password=None, new_password_valid=False)

  # Confirm password entry
  dut.confirm.value = 1
  await RisingEdge(dut.clk)
  dut.confirm.value = 0
  await RisingEdge(dut.clk)
  await RisingEdge(dut.clk)
  await RisingEdge(dut.clk)
  checker.process_input(key_input=None, confirm=True, admin_override=False, admin_set_mode=False, new_password=None, new_password_valid=False)

  assert_outputs(checker, dut)

async def admin_override(checker, dut):
  dut.admin_override.value = 1
  await RisingEdge(dut.clk)
  dut.admin_override.value = 0
  await RisingEdge(dut.clk)
  await RisingEdge(dut.clk)
  checker.process_input(key_input=None, confirm=False, admin_override=True, admin_set_mode=False, new_password=None, new_password_valid=False)
  assert_outputs(checker, dut)

async def set_new_password(checker, dut, new_password):
  dut.admin_set_mode.value = 1
  dut.admin_override.value = 1
  await RisingEdge(dut.clk)
  # Construct the full new password as a packed integer
  new_password_value = 0
  for i, digit in enumerate(reversed(new_password)):  # Reverse to correctly align bits
    new_password_value |= digit << (4 * i)  # Each digit occupies 4 bits
  dut.new_password.value = new_password_value
  dut.new_password_valid.value = 1
  await RisingEdge(dut.clk)
  dut.new_password_valid.value = 0
  dut.admin_set_mode.value = 0
  dut.admin_override.value = 0
  checker.process_input(key_input=None, confirm=False, admin_override=True, admin_set_mode=True, new_password=new_password, new_password_valid=True)

async def test_early_confirm(checker, dut, password_length, max_trials):
    print(f"Test: Confirm pressed before entering full password")

    partial_entry = [random.randint(0, 9) for _ in range(password_length - 2)]
    # Enter fewer digits than PASSWORD_LENGTH
    for digit in partial_entry:
        dut.key_input.value = digit
        dut.key_valid.value = 1
        await RisingEdge(dut.clk)
        dut.key_valid.value = 0
        await RisingEdge(dut.clk)
        checker.process_input(
            key_input=digit,
            confirm=False,
            admin_override=False,
            admin_set_mode=False,
            new_password=None,
            new_password_valid=False,
        )

    # Press confirm too early
    dut.confirm.value = 1
    await RisingEdge(dut.clk)
    dut.confirm.value = 0
    await RisingEdge(dut.clk)
    checker.process_input(
        key_input=None,
        confirm=True,
        admin_override=False,
        admin_set_mode=False,
        new_password=None,
        new_password_valid=False,
    )
    assert_outputs(checker, dut)

    print(f"System locked out after {max_trials} early confirms")


@cocotb.test()
async def test_door_lock(dut):

  # Start the clock with a 10ns period
  cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

  # Initialize DUT inputs
  await dut_init(dut)

  # Apply reset to DUT
  await reset_dut(dut)

  # Wait for a few clock cycles to ensure proper initialization
  for k in range(10):
    await RisingEdge(dut.clk)

  # Retrieve DUT configuration parameters
  password_length = int(dut.PASSWORD_LENGTH.value)
  max_trials = int(dut.MAX_TRIALS.value)
  num_samples = 30
  default_password = [0x0] * (password_length - 1) + [0x1]

  # Print parameters for debugging
  print(f"PASSWORD_LENGTH: {password_length}")
  print(f"MAX_TRIALS: {max_trials}")

  checker = DoorLockChecker(default_password, password_length, max_trials)

  # Test 1: Enter correct password
  print(f"Test 1: Enter correct password")
  await RisingEdge(dut.clk)
  await enter_password(checker, dut, default_password)

  # Test 2: Enter incorrect password
  print(f"Test 2: Enter incorrect password")
  # Generate an incorrect password of the same length as default_password
  incorrect_pass = [random.randint(0, 9) for x in default_password]  # Shift each digit by 1 (modulo 10)

  # Ensure incorrect_pass is different from default_password
  if incorrect_pass == default_password:
      incorrect_pass[0] = (incorrect_pass[0] + 2) % 10  # Modify the first element if needed

  await enter_password(checker, dut, incorrect_pass)

  # Test 3: Verify lockout
  print(f"Test 3: Verify lockout")
  # Attempt incorrect passwords multiple times to trigger lockout
  for _ in range(max_trials-1):
    # Generate an incorrect password of the same length as default_password
    incorrect_pass = [random.randint(0, 9) for x in default_password]  # Shift each digit by 1 (modulo 10)

    # Ensure incorrect_pass is different from default_password
    if incorrect_pass == default_password:
        incorrect_pass[0] = (incorrect_pass[0] + 2) % 10  # Modify the first element if needed

    await enter_password(checker, dut, incorrect_pass)

  assert dut.lockout.value == 1, f"System should be locked out after {max_trials} failed attempts, but lockout={dut.lockout.value}"

  # Test 4: Admin override to unlock
  print(f"Test 4: Admin override to unlock")
  await admin_override(checker, dut)

  # Test 5: Change password in Admin Mode
  print(f"Test 5: Change password in Admin Mode")
  # Generate an new password of the same length as default_password
  new_password = [random.randint(0, 9) for x in default_password]
  await set_new_password(checker, dut, new_password)

  # Test 6: Verify new password works
  print(f"Test 6: Verify new password works")
  await enter_password(checker, dut, new_password)

  # Test 6: Early confirm
  print(f"Test 7: Early confirm during password")
  await test_early_confirm(checker, dut, password_length, max_trials)

  print(f"All test cases passed!")

  # Wait for a few cycles before performing a final reset
  for k in range(2):
    await RisingEdge(dut.clk)

  # Apply a final reset to the DUT
  await reset_dut(dut)

  # Wait for a few cycles after reset to stabilize
  for k in range(2):
    await RisingEdge(dut.clk)

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import math

class JPEGRLEReference:
    """Reference model for JPEG Run-Length Encoding (RLE) behavior"""
    def __init__(self):
        self.zero_run = 0      # Current count of consecutive zeros
        self.block_pos = 0     # Position in current block (0-63)
        self.block_size = 64   # JPEG block size (8x8)
        self.debug = True      # Debug print enable
    
    def process_sample(self, sample, is_block_start):
        """Process a single sample through the reference model"""
        outputs = []
        
        if is_block_start:
            # DC term processing (must be first in block)
            if self.debug:
                print(f"\n[REF] BLOCK START: DC = {sample}")
            self.block_pos = 0
            self.zero_run = 0
            size = self.get_size(sample)
            outputs.append((0, size, sample, True))  # (rlen, size, amp, is_dc)
        else:
            # AC term processing
            self.block_pos += 1
            if self.debug:
                print(f"[REF] AC #{self.block_pos}: Input = {sample}, Zero Run = {self.zero_run}")
            
            if sample == 0:
                self.zero_run += 1
                if self.zero_run == 16:
                    # Emit Zero Run Length (ZRL) marker (15,0)
                    if self.debug:
                        print("[REF] Emitting ZRL (15,0,0)")
                    outputs.append((15, 0, 0, False))
                    self.zero_run = 0
            else:
                # Emit pending zeros followed by current non-zero value
                if self.zero_run > 0:
                    size = self.get_size(sample)
                    if self.debug:
                        print(f"[REF] Emitting (rlen={self.zero_run}, size={size}, amp={sample})")
                    outputs.append((self.zero_run, size, sample, False))
                    self.zero_run = 0
                else:
                    # Immediate non-zero value
                    size = self.get_size(sample)
                    if self.debug:
                        print(f"[REF] Emitting (rlen=0, size={size}, amp={sample})")
                    outputs.append((0, size, sample, False))
            
            # Check for End-of-Block (EOB)
            if self.block_pos == self.block_size - 1 and self.zero_run > 0:
                if self.debug:
                    print("[REF] Emitting EOB (0,0,0)")
                outputs.append((0, 0, 0, False))  # EOB marker
        
        return outputs
    
    def get_size(self, value):
        """Calculate the size/category for a given value"""
        abs_val = abs(value)
        return math.ceil(math.log2(abs_val + 1)) if abs_val != 0 else 0

async def initialize_dut(dut):
    """Initialize the DUT with proper reset sequence"""
    dut.reset_in.value = 1
    dut.enable_in.value = 0
    dut.dstrb_in.value = 0
    dut.din_in.value = 0

    # Start clock generator
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())

    # Wait for two clock edges
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    # Activate reset and enable
    dut.reset_in.value = 0
    dut.enable_in.value = 1

    await RisingEdge(dut.clk_in)
    print("\n[TB] DUT initialized\n")

async def apply_input(dut, sample, is_block_start):
    """Apply input to DUT and print debug info"""
    print(f"[IN] {'DC' if is_block_start else 'AC'}: {sample} (dstrb_in={1 if is_block_start else 0})")
    dut.din_in.value = sample
    dut.dstrb_in.value = 1 if is_block_start else 0
    await RisingEdge(dut.clk_in)
    dut.dstrb_in.value = 0

async def verify_output(dut, expected, test_case, cycle):
    """Verify DUT output against expected values"""
    if dut.douten_out.value == 1:
        actual = (
            int(dut.rlen_out.value),
            int(dut.size_out.value),
            int(dut.amp_out.value.signed_integer),
            bool(dut.bstart_out.value)
        )
        
        print(f"\n[TEST {test_case}.{cycle}] OUTPUT COMPARISON:")
        print("="*50)
        print(f"[ACTUAL]   rlen={actual[0]}, size={actual[1]}, amp={actual[2]}, bstart={actual[3]}")
        print(f"[EXPECTED] rlen={expected[0]}, size={expected[1]}, amp={expected[2]}, bstart={expected[3]}")
        print("="*50)
        
        assert actual == expected, f"Test {test_case}.{cycle} failed: Expected {expected}, got {actual}"
        return True
    return False

# =============================================================================
# Test Case 1: Basic Functional Test
# =============================================================================
@cocotb.test()
async def test_basic_functionality(dut):
    """Test basic functionality with mixed coefficients"""
    await initialize_dut(dut)
    ref_model = JPEGRLEReference()
    
    print(f"\n{'='*60}")
    print("TEST CASE 1: Basic block with mixed coefficients")
    print(f"{'='*60}\n")
    
    # DC term
    sample = 42
    expected_outputs = ref_model.process_sample(sample, True)
    await apply_input(dut, sample, True)
    await verify_output(dut, expected_outputs[0], 1, 1)
    
    # AC terms
    samples = [0, 0, 15, 0, 127] + [0]*59
    for i, sample in enumerate(samples, 2):  # Start counting from 2 (after DC)
        expected_outputs = ref_model.process_sample(sample, False)
        await apply_input(dut, sample, False)
        
        for expected in expected_outputs:
            if await verify_output(dut, expected, 1, i):
                await RisingEdge(dut.clk_in)

# =============================================================================
# Test Case 2: Zero Run Length (ZRL) Handling
# =============================================================================
@cocotb.test()
async def test_zrl_handling(dut):
    """Test Zero Run Length (15,0) sequences"""
    await initialize_dut(dut)
    ref_model = JPEGRLEReference()
    
    print(f"\n{'='*60}")
    print("TEST CASE 2: Block with Zero Run Length (ZRL)")
    print(f"{'='*60}\n")
    
    # DC term
    sample = 128
    expected_outputs = ref_model.process_sample(sample, True)
    await apply_input(dut, sample, True)
    await verify_output(dut, expected_outputs[0], 2, 1)
    
    # 16 zeros (should produce ZRL:15,0)
    samples = [0]*16 + [255] + [0]*47
    for i, sample in enumerate(samples, 2):
        expected_outputs = ref_model.process_sample(sample, False)
        await apply_input(dut, sample, False)
        
        for expected in expected_outputs:
            if await verify_output(dut, expected, 2, i):
                await RisingEdge(dut.clk_in)

# =============================================================================
# Test Case 3: End-of-Block (EOB) Handling
# =============================================================================
@cocotb.test()
async def test_eob_handling(dut):
    """Test End-of-Block (0,0) marker generation"""
    await initialize_dut(dut)
    ref_model = JPEGRLEReference()
    
    print(f"\n{'='*60}")
    print("TEST CASE 3: All zeros after DC (EOB only)")
    print(f"{'='*60}\n")
    
    # DC term
    sample = 64
    expected_outputs = ref_model.process_sample(sample, True)
    await apply_input(dut, sample, True)
    await verify_output(dut, expected_outputs[0], 3, 1)
    
    # All zeros (should produce EOB immediately)
    samples = [0]*63
    for i, sample in enumerate(samples, 2):
        expected_outputs = ref_model.process_sample(sample, False)
        await apply_input(dut, sample, False)
        
        for expected in expected_outputs:
            if await verify_output(dut, expected, 3, i):
                await RisingEdge(dut.clk_in)

# =============================================================================
# Test Case 4: Negative Coefficient Handling
# =============================================================================
@cocotb.test()
async def test_negative_coefficients(dut):
    """Test negative coefficient handling"""
    await initialize_dut(dut)
    ref_model = JPEGRLEReference()
    
    print(f"\n{'='*60}")
    print("TEST CASE 4: Negative coefficients")
    print(f"{'='*60}\n")
    
    # DC term (must be positive)
    sample = 64
    expected_outputs = ref_model.process_sample(sample, True)
    await apply_input(dut, sample, True)
    await verify_output(dut, expected_outputs[0], 4, 1)
    
    # AC terms with negative values
    samples = [-5, 0, 0, -12, -25, 0, -3] + [0]*57
    for i, sample in enumerate(samples, 2):
        expected_outputs = ref_model.process_sample(sample, False)
        await apply_input(dut, sample, False)
        
        for expected in expected_outputs:
            if await verify_output(dut, expected, 4, i):
                await RisingEdge(dut.clk_in)

# =============================================================================
# Test Case 5: Multiple ZRL Sequences
# =============================================================================
@cocotb.test()
async def test_multiple_zrl_sequences(dut):
    """Test multiple Zero Run Length sequences in one block"""
    await initialize_dut(dut)
    ref_model = JPEGRLEReference()
    
    print(f"\n{'='*60}")
    print("TEST CASE 5: Multiple ZRL sequences")
    print(f"{'='*60}\n")
    
    # DC term
    sample = 100
    expected_outputs = ref_model.process_sample(sample, True)
    await apply_input(dut, sample, True)
    await verify_output(dut, expected_outputs[0], 5, 1)
    
    # Create multiple ZRL sequences (16+ zeros) with values in between
    samples = [0]*20 + [5] + [0]*18 + [10] + [0]*24
    for i, sample in enumerate(samples, 2):
        expected_outputs = ref_model.process_sample(sample, False)
        await apply_input(dut, sample, False)
        
        for expected in expected_outputs:
            if await verify_output(dut, expected, 5, i):
                await RisingEdge(dut.clk_in)

# =============================================================================
# Test Case 6: Consecutive ZRL and Single Non-Zero
# =============================================================================
@cocotb.test()
async def test_consecutive_zrl(dut):
    """Test consecutive ZRL sequences with single non-zero"""
    await initialize_dut(dut)
    ref_model = JPEGRLEReference()
    
    print(f"\n{'='*60}")
    print("TEST CASE 6: Consecutive ZRL and single non-zero")
    print(f"{'='*60}\n")
    
    # DC term
    sample = -32
    expected_outputs = ref_model.process_sample(sample, True)
    await apply_input(dut, sample, True)
    await verify_output(dut, expected_outputs[0], 6, 1)
    
    # 32 zeros (should produce two ZRLs)
    samples = [0]*32 + [10] + [0]*31
    for i, sample in enumerate(samples, 2):
        expected_outputs = ref_model.process_sample(sample, False)
        await apply_input(dut, sample, False)
        
        for expected in expected_outputs:
            if await verify_output(dut, expected, 6, i):
                await RisingEdge(dut.clk_in)

# =============================================================================
# Test Case 7: Large Negative DC with All Zeros
# =============================================================================
@cocotb.test()
async def test_large_negative_dc(dut):
    """Test large negative DC coefficient with all zero AC"""
    await initialize_dut(dut)
    ref_model = JPEGRLEReference()
    
    print(f"\n{'='*60}")
    print("TEST CASE 7: Large negative DC with all zeros")
    print(f"{'='*60}\n")
    
    # DC term
    sample = -2047
    expected_outputs = ref_model.process_sample(sample, True)
    await apply_input(dut, sample, True)
    await verify_output(dut, expected_outputs[0], 7, 1)
    
    # All zeros (should produce EOB)
    samples = [0]*63
    for i, sample in enumerate(samples, 2):
        expected_outputs = ref_model.process_sample(sample, False)
        await apply_input(dut, sample, False)
        
        for expected in expected_outputs:
            if await verify_output(dut, expected, 7, i):
                await RisingEdge(dut.clk_in)



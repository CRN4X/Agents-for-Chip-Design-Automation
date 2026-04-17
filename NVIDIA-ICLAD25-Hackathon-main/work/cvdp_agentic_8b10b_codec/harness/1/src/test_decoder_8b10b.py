import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
from collections import deque

# Special character code values
K28d0_RD0 = "0011110100"
K28d0_RD1 = "1100001011"
K28d1_RD0 = "0011111001"
K28d1_RD1 = "1100000110"
K28d2_RD0 = "0011110101"
K28d2_RD1 = "1100001010"
K28d3_RD0 = "0011110011"
K28d3_RD1 = "1100001100"
K28d4_RD0 = "0011110010"
K28d4_RD1 = "1100001101"
K28d5_RD0 = "0011111010"
K28d5_RD1 = "1100000101"
K28d6_RD0 = "0011110110"
K28d6_RD1 = "1100001001"
K28d7_RD0 = "0011111000"
K28d7_RD1 = "1100000111"
K23d7_RD0 = "1110101000"
K23d7_RD1 = "0001010111"
K27d7_RD0 = "1101101000"
K27d7_RD1 = "0010010111"
K29d7_RD0 = "1011101000"
K29d7_RD1 = "0100010111"
K30d7_RD0 = "0111101000"
K30d7_RD1 = "1000010111"

async def initialize_dut(dut):
    """Initialize the DUT and start the clock."""
    dut.reset_in.value = 1
    dut.decoder_in.value = 0
    dut.decoder_valid_in.value = 0
    dut.control_in.value = 0

    clock = Clock(dut.clk_in, 50, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    dut.reset_in.value = 0

async def check_output(dut, expected_value, expected_control, input_value):
    """Check the output of the DUT against the expected value."""
    expected_value_bin = f"{int(expected_value, 16):08b}"  # Convert hex to binary
    print(f"Expected: {hex(int(expected_value, 16)):>4}, Got: {hex(int(str(dut.decoder_out.value), 2)):>4}, Input: {input_value}")
    assert str(dut.decoder_out.value) == expected_value_bin, f"Expected {expected_value_bin}, got {str(dut.decoder_out.value)}"
    assert dut.control_out.value == expected_control, f"Expected control {expected_control}, got {dut.control_out.value}"

def calculate_expected_value(codeword):
    """Calculate the expected value based on the 10-bit codeword."""
    if codeword in [K28d0_RD0, K28d0_RD1]:
        return "1C"
    elif codeword in [K28d1_RD0, K28d1_RD1]:
        return "3C"
    elif codeword in [K28d2_RD0, K28d2_RD1]:
        return "5C"
    elif codeword in [K28d3_RD0, K28d3_RD1]:
        return "7C"
    elif codeword in [K28d4_RD0, K28d4_RD1]:
        return "9C"
    elif codeword in [K28d5_RD0, K28d5_RD1]:
        return "BC"
    elif codeword in [K28d6_RD0, K28d6_RD1]:
        return "DC"
    elif codeword in [K28d7_RD0, K28d7_RD1]:
        return "FC"
    elif codeword in [K23d7_RD0, K23d7_RD1]:
        return "F7"
    elif codeword in [K27d7_RD0, K27d7_RD1]:
        return "FB"
    elif codeword in [K29d7_RD0, K29d7_RD1]:
        return "FD"
    elif codeword in [K30d7_RD0, K30d7_RD1]:
        return "FE"
    else:
        return "00"

# Data symbols for 8b10b decoder
DATA_SYMBOLS = [
     "1001110100", "0110001011", "0111010010", "1000101101", "1011010101", "0100100101", "1100010110", "1100010110",
     "0111010100", "1000101011", "1011010010", "0100101101", "1100010101", "1100010101", "1101010110", "0010100110",
     "1011010100", "0100101011", "1100011101", "1100010010", "1101010101", "0010100101", "1010010110", "1010010110",
     "1100011011", "1100010100", "1101010010", "0010101101", "1010010101", "1010010101", "0110010110", "0110010110",
     "1101010100", "0010101011", "1010011101", "1010010010", "0110010101", "0110010101", "1110000110", "0001110110",
     "1010011011", "1010010100", "0110011101", "0110010010", "1110000101", "0001110101", "1110010110", "0001100110",
     "0110011011", "0110010100", "1110001101", "0001110010", "1110010101", "0001100101", "1001010110", "1001010110",
     "1110001011", "0001110100", "1110010010", "0001101101", "1001010101", "1001010101", "0101010110", "0101010110",
     "1110010100", "0001101011", "1001011101", "1001010010", "0101010101", "0101010101", "1101000110", "1101000110",
     "1001011011", "1001010100", "0101011101", "0101010010", "1101000101", "1101000101", "0011010110", "0011010110",
     "0101011011", "0101010100", "1101001101", "1101000010", "0011010101", "0011010101", "1011000110", "1011000110",
     "1101001011", "1101000100", "0011011101", "0011010010", "1011000101", "1011000101", "0111000110", "0111000110",
     "0011011011", "0011010100", "1011001101", "1011000010", "0111000101", "0111000101", "0101110110", "1010000110",
     "1011001011", "1011000100", "0111001101", "0111000010", "0101110101", "1010000101", "0110110110", "1001000110",
     "0111001011", "0111000100", "0101110010", "1010001101", "0110110101", "1001000101", "1000110110", "1000110110",
     "0101110100", "1010001011", "0110110010", "1001001101", "1000110101", "1000110101", "0100110110", "0100110110",
     "0110110100", "1001001011", "1000111101", "1000110010", "0100110101", "0100110101", "1100100110", "1100100110",
     "1000111011", "1000110100", "0100111101", "0100110010", "1100100101", "1100100101", "0010110110", "0010110110",
     "0100111011", "0100110100", "1100101101", "1100100010", "0010110101", "0010110101", "1010100110", "1010100110",
     "1100101011", "1100100100", "0010111101", "0010110010", "1010100101", "1010100101", "0110100110", "0110100110",
     "0010111011", "0010110100", "1010101101", "1010100010", "0110100101", "0110100101", "1110100110", "0001010110",
     "1010101011", "1010100100", "0110101101", "0110100010", "1110100101", "0001010101", "1100110110", "0011000110",
     "0110101011", "0110100100", "1110100010", "0001011101", "1100110101", "0011000101", "1001100110", "1001100110",
     "1110100100", "0001011011", "1100110010", "0011001101", "1001100101", "1001100101", "0101100110", "0101100110",
     "1100110100", "0011001011", "1001101101", "1001100010", "0101100101", "0101100101", "1101100110", "0010010110",
     "1001101011", "1001100100", "0101101101", "0101100010", "1101100101", "0010010101", "0011100110", "0011100110",
     "0101101011", "0101100100", "1101100010", "0010011101", "0011100101", "0011100101", "1011100110", "0100010110",
     "1101100100", "0010011011", "0011101101", "0011100010", "1011100101", "0100010101", "0111100110", "1000010110",
     "0011101011", "0011100100", "1011100010", "0100011101", "0111100101", "1000010101", "1010110110", "0101000110",
     "1011100100", "0100011011", "0111100010", "1000011101", "1010110101", "0101000101", "1001110001", "0110001110",
     "0111100100", "1000011011", "1010110010", "0101001101", "1001110011", "0110001100", "0111010001", "1000101110",
     "1010110100", "0101001011", "1001111010", "0110001010", "0111010011", "1000101100", "1011010001", "0100101110",
     "1001111001", "0110001001", "0111011010", "1000101010", "1011010011", "0100101100", "1100011110", "1100010001",
     "0111011001", "1000101001", "1011011010", "0100101010", "1100011100", "1100010011", "1101010001", "0010101110",
     "1011011001", "0100101001", "1100011010", "1100011010", "1101010011", "0010101100", "1010011110", "1010010001",
     "1100011001", "1100011001", "1101011010", "0010101010", "1010011100", "1010010011", "0110011110", "0110010001",
     "1101011001", "0010101001", "1010011010", "1010011010", "0110011100", "0110010011", "1110001110", "0001110001",
     "1010011001", "1010011001", "0110011010", "0110011010", "1110001100", "0001110011", "1110010001", "0001101110",
     "0110011001", "0110011001", "1110001010", "0001111010", "1110010011", "0001101100", "1001011110", "1001010001",
     "1110001001", "0001111001", "1110011010", "0001101010", "1001011100", "1001010011", "0101011110", "0101010001",
     "1110011001", "0001101001", "1001011010", "1001011010", "0101011100", "0101010011", "1101001110", "1101001000",
     "1001011001", "1001011001", "0101011010", "0101011010", "1101001100", "1101000011", "0011011110", "0011010001",
     "0101011001", "0101011001", "1101001010", "1101001010", "0011011100", "0011010011", "1011001110", "1011001000",
     "1101001001", "1101001001", "0011011010", "0011011010", "1011001100", "1011000011", "0111001110", "0111001000",
     "0011011001", "0011011001", "1011001010", "1011001010", "0111001100", "0111000011", "0101110001", "1010001110",
     "1011001001", "1011001001", "0111001010", "0111001010", "0101110011", "1010001100", "0110110001", "1001001110",
     "0111001001", "0111001001", "0101111010", "1010001010", "0110110011", "1001001100", "1000110111", "1000110001",
     "0101111001", "1010001001", "0110111010", "1001001010", "1000111100", "1000110011", "0100110111", "0100110001",
     "0110111001", "1001001001", "1000111010", "1000111010", "0100111100", "0100110011", "1100101110", "1100100001",
     "1000111001", "1000111001", "0100111010", "0100111010", "1100101100", "1100100011", "0010110111", "0010110001",
     "0100111001", "0100111001", "1100101010", "1100101010", "0010111100", "0010110011", "1010101110", "1010100001",
     "1100101001", "1100101001", "0010111010", "0010111010", "1010101100", "1010100011", "0110101110", "0110100001",
     "0010111001", "0010111001", "1010101010", "1010101010", "0110101100", "0110100011", "1110100001", "0001011110",
     "1010101001", "1010101001", "0110101010", "0110101010", "1110100011", "0001011100", "1100110001", "0011001110",
     "0110101001", "0110101001", "1110101010", "0001011010", "1100110011", "0011001100", "1001101110", "1001100001",
     "1110101001", "0001011001", "1100111010", "0011001010", "1001101100", "1001100011", "0101101110", "0101100001",
     "1100111001", "0011001001", "1001101010", "1001101010", "0101101100", "0101100011", "1101100001", "0010011110",
     "1001101001", "1001101001", "0101101010", "0101101010", "1101100011", "0010011100", "0011101110", "0011100001",
     "0101101001", "0101101001", "1101101010", "0010011010", "0011101100", "0011100011", "1011100001", "0100011110",
     "1101101001", "0010011001", "0011101010", "0011101010", "1011100011", "0100011100", "0111100001", "1000011110",
     "0011101001", "0011101001", "1011101010", "0100011010", "0111100011", "1000011100", "1010110001", "0101001110",
     "1011101001", "0100011001", "0111101010", "1000011010", "1010110011", "0101001100", "1001110010", "0110001101",
     "0111101001", "1000011001", "1010111010", "0101001010", "1001110101", "0110000101", "0111010110", "1000100110",
     "1010111001", "0101001001", "1001110110", "0110000110", "0111010101", "1000100101", "1011010110", "0100100110" 
]
async def initialize_dut(dut):
    """Initialize the DUT and start the clock."""
    dut.reset_in.value = 1
    dut.decoder_in.value = 0
    dut.decoder_valid_in.value = 0
    dut.control_in.value = 0

    clock = Clock(dut.clk_in, 50, units="ns")
    cocotb.start_soon(clock.start())

    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)

    dut.reset_in.value = 0

def calculate_doi(d):
    d = [int(bit) for bit in f"{int(d, 2):010b}"][::-1] 
    def not_(x): return 1 if x == 0 else 0

    doi = [0] * 8

    doi[7] = (((d[0] ^ d[1]) & not_(
        (not_(d[3]) & d[2] & not_(d[1]) & d[0] & not_(not_(d[7] | d[6] | d[5] | d[4]))) |
        (not_(d[3]) & d[2] & d[1] & not_(d[0]) & not_(d[7] | d[6] | d[5] | d[4])) |
        (d[3] & not_(d[2]) & not_(d[1]) & d[0] & not_(not_(d[7] | d[6] | d[5] | d[4]))) |
        (d[3] & not_(d[2]) & d[1] & not_(d[0]) & not_(d[7] | d[6] | d[5] | d[4]))
    ))) | (not_(d[3]) & d[2] & d[1] & d[0]) | (d[3] & not_(d[2]) & not_(d[1]) & not_(d[0]))

    doi[6] = ((d[0] & not_(d[3]) & (d[1] | not_(d[2]) | not_(not_(d[7] | d[6] | d[5] | d[4])))) |
              (d[3] & not_(d[0]) & (not_(d[1]) | d[2] | not_(d[7] | d[6] | d[5] | d[4]))) |
              (not_(not_(d[7] | d[6] | d[5] | d[4])) & d[2] & d[1]) |
              (not_(d[7] | d[6] | d[5] | d[4]) & not_(d[2]) & not_(d[1])))

    doi[5] = ((d[0] & not_(d[3]) & (d[1] | not_(d[2]) | not_(d[7] | d[6] | d[5] | d[4]))) |
              (d[3] & not_(d[0]) & (not_(d[1]) | d[2] | not_(not_(d[7] | d[6] | d[5] | d[4])))) |
              (not_(d[7] | d[6] | d[5] | d[4]) & d[2] & d[1]) |
              (not_(not_(d[7] | d[6] | d[5] | d[4])) & not_(d[2]) & not_(d[1])))

    

    term32 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term33 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term34 = (term32 | term33) & not_(d[5])
    term35 = not_(d[7]) & not_(d[6]) & not_(d[5]) & not_(d[4])
    term36 = not_(d[9]) & not_(d[8]) & not_(d[5]) & not_(d[4])
    term37 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term38 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term39 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term40 = (term37 | term38 | term39) & not_(d[9]) & not_(d[7]) & not_(d[5] ^ d[4])
    term41 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term42 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term43 = (term41 | term42) & not_(d[4])
    term44 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term45 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term46 = (term44 | term45) & d[6] & d[5] & d[4]
    term47 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term48 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term49 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term50 = (term47 | term48 | term49) & not_(d[8]) & not_(d[7]) & not_(d[5] ^ d[4])

    doi[4] = d[5] ^ (term34 | term35 | term36 | term40 | term43 | term46 | term50)

    term1 = d[9] & d[8] & d[5] & d[4]
    term2 = not_(d[7]) & not_(d[6]) & not_(d[5]) & not_(d[4])
    term3 = (not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & d[7] & d[6])
    term4 = (not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & d[9] & d[8])
    term5 = (term3 | term4) & d[4]

    term6 = (
        ((d[9] & d[8] & not_(d[7]) & not_(d[6])) |
         (d[7] & d[6] & not_(d[9]) & not_(d[8])) |
         (not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))))
        ) & d[9] & d[7] & not_(d[5] ^ d[4])
    )
    term7 = (
        (not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])) |
        (not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8]))
    ) & not_(d[5])
    term8 = (
        (not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])) |
        (not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8]))
    ) & d[6] & d[5] & d[4]
    term9 = (
        ((d[9] & d[8] & not_(d[7]) & not_(d[6])) |
         (d[7] & d[6] & not_(d[9]) & not_(d[8])) |
         (not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))))
        ) & not_(d[8]) & not_(d[7]) & not_(d[5] ^ d[4])
    )

    doi[3] = d[6] ^ (term1 | term2 | term5 | term6 | term7 | term8 | term9)


    
    term10 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term11 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term12 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term13 = (term10 | term11 | term12) & not_(d[9]) & not_(d[7]) & not_(d[5] ^ d[4])
    term14 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term15 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term16 = (term14 | term15) & not_(d[5])
    term17 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & d[7] & d[6]
    term18 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & d[9] & d[8]
    term19 = (term17 | term18) & d[4]
    term20 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term21 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term22 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term23 = (term20 | term21 | term22) & d[8] & d[7] & not_(d[5] ^ d[4])
    term24 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term25 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term26 = (term24 | term25) & d[6] & d[5] & d[4]
    term27 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term28 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term29 = (term27 | term28) & not_(d[5])
    term30 = not_(d[7]) & not_(d[6]) & not_(d[5]) & not_(d[4])
    term31 = not_(d[9]) & not_(d[8]) & not_(d[5]) & not_(d[4])

    doi[2] = d[7] ^ (term13 | term16 | term19 | term23 | term26 | term29 | term30 | term31)

       
    term51 = d[9] & d[8] & d[5] & d[4]
    term52 = not_(d[7]) & not_(d[6]) & not_(d[5]) & not_(d[4])
    term53 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & d[7] & d[6]
    term54 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & d[9] & d[8]
    term55 = (term53 | term54) & d[4]
    term56 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & d[7] & d[6]
    term57 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & d[9] & d[8]
    term58 = (term56 | term57) & d[4]
    term59 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term60 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term61 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term62 = (term59 | term60 | term61) & d[8] & d[7] & not_(d[5] ^ d[4])
    term63 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term64 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term65 = (term63 | term64) & d[6] & d[5] & d[4]
    term66 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term67 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term68 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term69 = (term66 | term67 | term68) & d[9] & d[7] & not_(d[5] ^ d[4])
    term70 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term71 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term72 = (term70 | term71) & not_(d[5])

    doi[1] = d[8] ^ (term51 | term52 | term55 | term58 | term62 | term65 | term69 | term72)

   
    term73 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term74 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term75 = (term73 | term74) & d[6] & d[5] & d[4]
    term76 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term77 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term78 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term79 = (term76 | term77 | term78) & not_(d[8]) & not_(d[7]) & not_(d[5] ^ d[4])
    term80 = d[9] & d[8] & not_(d[7]) & not_(d[6])
    term81 = d[7] & d[6] & not_(d[9]) & not_(d[8])
    term82 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6])))
    term83 = (term80 | term81 | term82) & not_(d[9]) & not_(d[7]) & not_(d[5] ^ d[4])
    term84 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & not_(d[7]) & not_(d[6])
    term85 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & not_(d[9]) & not_(d[8])
    term86 = (term84 | term85) & not_(d[5])
    term87 = d[9] & d[8] & d[5] & d[4]
    term88 = not_(d[7]) & not_(d[6]) & not_(d[5]) & not_(d[4])
    term89 = not_((d[9] & d[8]) | (not_(d[9]) & not_(d[8]))) & d[7] & d[6]
    term90 = not_((d[7] & d[6]) | (not_(d[7]) & not_(d[6]))) & d[9] & d[8]
    term91 = (term89 | term90) & d[4]

    doi[0] = d[9] ^ (term75 | term79 | term83 | term86 | term87 | term88 | term91)

       
    return "".join(map(str, reversed(doi)))


@cocotb.test()
async def test_decoder_8b10b_reset(dut):
    """Test sending any random control symbol continuously out of 12 symbols and reset HIGH."""
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(10):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 1
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"

        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

    dut.reset_in.value = 1
    await RisingEdge(dut.clk_in)
    await RisingEdge(dut.clk_in)
    expected_value = "00"
    expected_control = 0
    await check_output(dut, expected_value, expected_control, "0000000000")

@cocotb.test()
async def test_continuous_control_symbol(dut):
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(28):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 1
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

    await Timer(100, units="ns")


@cocotb.test()
async def test_random_control_symbol(dut):
    """Test sending any random control symbol continuously out of 12 symbols."""
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(10):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 1
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

@cocotb.test()
async def test_same_control_symbol(dut):
    """Test sending the same control symbol continuously."""
    await initialize_dut(dut)

    control_symbols = [K28d6_RD0, K28d6_RD1]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(20):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 1
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

@cocotb.test()
async def test_random_invalid_control_input(dut):
    """Test sending any 10-bit input other than 12 control symbols."""
    await initialize_dut(dut)

    control_symbols = [
        K28d0_RD0, K28d0_RD1, K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d4_RD0, K28d4_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1, K28d7_RD0, K28d7_RD1, K23d7_RD0, K23d7_RD1,
        K27d7_RD0, K27d7_RD1, K29d7_RD0, K29d7_RD1, K30d7_RD0, K30d7_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(10):  # Adjust the range as needed
        random_data = random.randint(0, 1023)
        while f"{random_data:010b}" in control_symbols:
            random_data = random.randint(0, 1023)
        dut.decoder_in.value = random_data
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 1
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

    await Timer(100, units="ns")

@cocotb.test()
async def test_random_imbalanced_control_symbol(dut):
    """Test sending any random control symbol continuously out of 5 imbalanced symbols."""
    await initialize_dut(dut)

    control_symbols = [
        K28d1_RD0, K28d1_RD1, K28d2_RD0, K28d2_RD1,
        K28d3_RD0, K28d3_RD1, K28d5_RD0, K28d5_RD1,
        K28d6_RD0, K28d6_RD1
    ]

    # Queue to store previous decoder_in values
    decoder_in_queue = deque([0, 0], maxlen=2)

    for _ in range(20):  # Adjust the range as needed
        random_symbol = random.choice(control_symbols)
        dut.decoder_in.value = int(random_symbol, 2)
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 1
        await RisingEdge(dut.clk_in)

        # Store the current decoder_in value in the queue
        decoder_in_queue.append(dut.decoder_in.value)

        # Use the delayed decoder_in value for comparison
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"
        expected_value = calculate_expected_value(delayed_decoder_in)
        expected_control = 1 if delayed_decoder_in in control_symbols else 0
        await check_output(dut, expected_value, expected_control, delayed_decoder_in)

@cocotb.test()
async def test_seq_data_symbols(dut):
    """Test sequential data symbols."""
    await initialize_dut(dut)

    default_value = int('1001110100', 2)  # This will be 628

    # Initialize the deque with the default value
    decoder_in_queue = deque([default_value, default_value], maxlen=2)

    for symbol in DATA_SYMBOLS:  # Iterate through all symbols in DATA_SYMBOLS
        dut.decoder_in.value = int(symbol, 2)
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 0  # Data symbols
        await RisingEdge(dut.clk_in)
        decoder_in_queue.append(dut.decoder_in.value)
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"

        # Wait for decoder_valid_out to be HIGH
        while not dut.decoder_valid_out.value:
            await RisingEdge(dut.clk_in)

        expected_value = calculate_doi(delayed_decoder_in)
        dut_doi = f"{int(dut.decoder_out.value):08b}"

        print(f"Expected: {hex(int(expected_value, 2)):>4}, Got: {hex(int(str(dut_doi), 2)):>4}, Input: {delayed_decoder_in}")

        assert dut_doi == expected_value, f"Mismatch: Input={symbol}, Expected={expected_value}, Got={dut_doi}"

@cocotb.test()
async def test_random_data_symbols(dut):
    """Test random data symbols with random selection for 10 cycles"""
    await initialize_dut(dut)

    default_value = int('1001110100', 2)  # This will be 628

    # Initialize the deque with the default value
    decoder_in_queue = deque([default_value, default_value], maxlen=2)

    for _ in range(10):  # Run for 10 cycles
        # Randomly select a symbol from DATA_SYMBOLS
        symbol = random.choice(DATA_SYMBOLS)
        dut.decoder_in.value = int(symbol, 2)
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 0  # Data symbols
        await RisingEdge(dut.clk_in)
        decoder_in_queue.append(dut.decoder_in.value)
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"

        # Wait for decoder_valid_out to be HIGH
        while not dut.decoder_valid_out.value:
            await RisingEdge(dut.clk_in)

        expected_value = calculate_doi(delayed_decoder_in)
        dut_doi = f"{int(dut.decoder_out.value):08b}"

        print(f"Expected: {hex(int(expected_value, 2)):>4}, Got: {hex(int(str(dut_doi), 2)):>4}, Input: {delayed_decoder_in}")

        assert dut_doi == expected_value, f"Mismatch: Input={symbol}, Expected={expected_value}, Got={dut_doi}"


# Define the allowed_values array
@cocotb.test()
async def test_incrementing_data_symbols(dut):
    """Test data symbols using the allowed_values array for 10 cycles"""
    await initialize_dut(dut)
    allowed_values = [
    0x274, 0x1d4, 0x2d4, 0x31b, 0x0ab, 0x294, 0x19b, 0x074,
    0x394, 0x25b, 0x154, 0x34b, 0x0d4, 0x2cb, 0x1c4, 0x174,
    0x1b4, 0x23b, 0x134, 0x32b, 0x0b4, 0x2ab, 0x1a4, 0x3a4
    ]

    default_value = int('1001110100', 2)  # This will be 628

    # Initialize the deque with the default value
    decoder_in_queue = deque([default_value, default_value], maxlen=2)

    for i in range(24):  # Run for 10 cycles
        symbol = allowed_values[i % len(allowed_values)]

        dut.decoder_in.value = symbol
        dut.decoder_valid_in.value = 1
        dut.control_in.value = 0  # Data symbols
        await RisingEdge(dut.clk_in)
        decoder_in_queue.append(dut.decoder_in.value)
        delayed_decoder_in = f"{int(decoder_in_queue[0]):010b}"

        # Wait for decoder_valid_out to be HIGH
        while not dut.decoder_valid_out.value:
            await RisingEdge(dut.clk_in)

        expected_value = calculate_doi(delayed_decoder_in)
        dut_doi = f"{int(dut.decoder_out.value):08b}"

        print(f"Expected: {hex(int(expected_value, 2)):>4}, Got: {hex(int(str(dut_doi), 2)):>4}, Input: {delayed_decoder_in}")

        assert dut_doi == expected_value, f"Mismatch: Input={symbol:03x}, Expected={expected_value}, Got={dut_doi}"


import os
from cocotb.runner import get_runner

def test_runner():
    verilog_sources = os.getenv("VERILOG_SOURCES").split()
    sim             = os.getenv("SIM", "icarus")
    toplevel        = os.getenv("TOPLEVEL")      # e.g., "swizzler"
    module          = os.getenv("MODULE")        # e.g., "test_swizzler"

    # Swizzler parameters (with defaults)
    num_lanes         = int(os.getenv("NUM_LANES", "4"))
    data_width        = int(os.getenv("DATA_WIDTH", "8"))
    register_output   = int(os.getenv("REGISTER_OUTPUT", "0"))
    enable_parity     = int(os.getenv("ENABLE_PARITY_CHECK", "0"))

    parameters = {
        "NUM_LANES":         num_lanes,
        "DATA_WIDTH":        data_width,
        "REGISTER_OUTPUT":   register_output,
        "ENABLE_PARITY_CHECK": enable_parity
    }

    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters,
        always=True,
        clean=True,
        waves=True,
        verbose=True,
        timescale=("1ns", "1ns"),
        log_file="build.log"
    )

    runner.test(
        hdl_toplevel=toplevel,
        test_module=module,
        waves=True
    )

if __name__ == "__main__":
    test_runner()

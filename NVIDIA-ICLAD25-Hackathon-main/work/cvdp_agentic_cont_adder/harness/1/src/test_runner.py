import os
from cocotb.runner import get_runner

def test_runner():
    verilog_sources   = os.getenv("VERILOG_SOURCES").split()
    sim               = os.getenv("SIM", "icarus")
    toplevel          = os.getenv("TOPLEVEL")       # "continuous_adder"
    module            = os.getenv("MODULE")         # "test_continuous_adder"

    data_width        = int(os.getenv("DATA_WIDTH", "32"))
    enable_threshold  = int(os.getenv("ENABLE_THRESHOLD", "0"))
    register_output   = int(os.getenv("REGISTER_OUTPUT", "0"))
    threshold_dec_str = os.getenv("THRESHOLD_DEC", "16")
    threshold_int     = int(threshold_dec_str, 0)

    parameters = {
        "DATA_WIDTH":        data_width,
        "ENABLE_THRESHOLD":  enable_threshold,
        "THRESHOLD":         threshold_int,   # integer param override
        "REGISTER_OUTPUT":   register_output
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

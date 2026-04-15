import os
from cocotb.runner import get_runner

def test_runner():
    verilog_sources = os.getenv("VERILOG_SOURCES").split()
    sim             = os.getenv("SIM", "icarus")
    toplevel        = os.getenv("TOPLEVEL")      # e.g., "multiplexer"
    module          = os.getenv("MODULE")        # e.g., "test_multiplexer"

    data_width       = int(os.getenv("DATA_WIDTH", "8"))
    num_inputs       = int(os.getenv("NUM_INPUTS", "4"))
    register_output  = int(os.getenv("REGISTER_OUTPUT", "0"))
    has_default      = int(os.getenv("HAS_DEFAULT", "0"))
    default_value    = os.getenv("DEFAULT_VALUE", "8'h00")

    # Parameters to pass into the Verilog
    parameters = {
        "DATA_WIDTH": data_width,
        "NUM_INPUTS": num_inputs,
        "REGISTER_OUTPUT": register_output,
        "HAS_DEFAULT": has_default,
        "DEFAULT_VALUE": default_value
    }

    runner = get_runner(sim)

    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=parameters,     # Pass parameters in
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

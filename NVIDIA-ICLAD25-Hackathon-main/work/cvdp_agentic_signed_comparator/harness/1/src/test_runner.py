import os
from cocotb.runner import get_runner

def test_runner():
    verilog_sources = os.getenv("VERILOG_SOURCES").split()
    sim             = os.getenv("SIM", "icarus")
    toplevel        = os.getenv("TOPLEVEL")
    module          = os.getenv("MODULE")

    dw_str          = os.getenv("DATA_WIDTH", "16")
    ro_str          = os.getenv("REGISTER_OUTPUT", "0")
    et_str          = os.getenv("ENABLE_TOLERANCE", "0")
    tol_str         = os.getenv("TOLERANCE", "0")
    sh_str          = os.getenv("SHIFT_LEFT", "0")

    params = {
        "DATA_WIDTH":       int(dw_str),
        "REGISTER_OUTPUT":  int(ro_str),
        "ENABLE_TOLERANCE": int(et_str),
        "TOLERANCE":        int(tol_str),
        "SHIFT_LEFT":       int(sh_str)
    }

    runner = get_runner(sim)
    runner.build(
        sources=verilog_sources,
        hdl_toplevel=toplevel,
        parameters=params,
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

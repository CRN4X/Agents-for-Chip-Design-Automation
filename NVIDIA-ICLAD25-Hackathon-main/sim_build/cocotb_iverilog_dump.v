module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("/Users/siddharth/Documents/EEE_598_VDA_Proj2/Proj2_Phase2/NVIDIA-ICLAD25-Hackathon-main/sim_build/poly_decimator.fst");
    end
    $dumpvars(0, poly_decimator);
end
endmodule

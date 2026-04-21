`timescale 1ns/1ns

module universal_shift_register #(
    parameter int N = 8
) (
    input  logic         clk,
    input  logic         rst,
    input  logic [1:0]   mode_sel,
    input  logic         shift_dir,
    input  logic         serial_in,
    input  logic [N-1:0] parallel_in,
    output logic [N-1:0] q,
    output logic         serial_out
);

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        q <= '0;
    end else begin
        unique case (mode_sel)
            2'b00: q <= q;                                // Hold
            2'b01: q <= shift_dir ? {q[N-2:0], serial_in} // Shift left
                                 : {serial_in, q[N-1:1]}; // Shift right
            2'b10: q <= shift_dir ? {q[N-2:0], q[N-1]}    // Rotate left
                                 : {q[0], q[N-1:1]};      // Rotate right
            2'b11: q <= parallel_in;                      // Parallel load
            default: q <= q;
        endcase
    end
end

always_comb begin
    serial_out = (shift_dir === 1'b1) ? q[N-1] : q[0];
end

endmodule

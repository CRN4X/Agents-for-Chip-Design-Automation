`timescale 1ns/1ns

module universal_shift_register #(
    parameter N = 8
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         en,
    input  wire [2:0]   op_sel,
    input  wire         shift_dir,
    input  wire         serial_in,
    input  wire [N-1:0] parallel_in,
    input  wire [1:0]   bitwise_op,
    output reg  [N-1:0] q,
    output wire         serial_out,
    output reg          overflow,
    output wire         parity_out,
    output wire         zero_flag,
    output wire         msb_out,
    output wire         lsb_out
);

    integer i;
    reg [N-1:0] reversed_q;

    always @(*) begin
        reversed_q = {N{1'b0}};
        for (i = 0; i < N; i = i + 1) begin
            reversed_q[i] = q[N-1-i];
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q        <= {N{1'b0}};
            overflow <= 1'b0;
        end else if (en) begin
            case (op_sel)
                3'b000: begin
                    q        <= q;
                    overflow <= 1'b0;
                end
                3'b001: begin
                    if (shift_dir == 1'b0) begin
                        overflow <= q[0];
                        q        <= {serial_in, q[N-1:1]};
                    end else begin
                        overflow <= q[N-1];
                        q        <= {q[N-2:0], serial_in};
                    end
                end
                3'b010: begin
                    if (shift_dir == 1'b0) begin
                        overflow <= q[0];
                        q        <= {q[0], q[N-1:1]};
                    end else begin
                        overflow <= q[N-1];
                        q        <= {q[N-2:0], q[N-1]};
                    end
                end
                3'b011: begin
                    q        <= parallel_in;
                    overflow <= 1'b0;
                end
                3'b100: begin
                    if (shift_dir == 1'b0) begin
                        overflow <= q[0];
                        q        <= {q[N-1], q[N-1:1]};
                    end else begin
                        overflow <= q[N-1];
                        q        <= {q[N-2:0], 1'b0};
                    end
                end
                3'b101: begin
                    case (bitwise_op)
                        2'b00: q <= q & parallel_in;
                        2'b01: q <= q | parallel_in;
                        2'b10: q <= q ^ parallel_in;
                        default: q <= ~(q ^ parallel_in);
                    endcase
                    overflow <= 1'b0;
                end
                3'b110: begin
                    q        <= reversed_q;
                    overflow <= 1'b0;
                end
                3'b111: begin
                    q        <= ~q;
                    overflow <= 1'b0;
                end
                default: begin
                    q        <= q;
                    overflow <= 1'b0;
                end
            endcase
        end
    end

    assign serial_out = (shift_dir == 1'b0) ? q[0] : q[N-1];
    assign parity_out = ^q;
    assign zero_flag  = (q == {N{1'b0}});
    assign msb_out    = q[N-1];
    assign lsb_out    = q[0];

endmodule

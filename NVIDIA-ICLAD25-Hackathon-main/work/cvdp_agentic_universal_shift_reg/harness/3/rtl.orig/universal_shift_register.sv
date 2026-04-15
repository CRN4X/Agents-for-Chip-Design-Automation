module universal_shift_register #(
    parameter N = 8                     // Width of the register
)(
    input wire clk,                     // Clock signal
    input wire rst,                     // Synchronous reset
    input wire [1:0] mode_sel,          // Mode select [00 - Hold, 01 - Shift, 10 - Rotate, 11 - Parallel Load]
    input wire shift_dir,               // 0 = Shift Right, 1 = Shift Left
    input wire serial_in,               // Serial input for SISO, PISO
    input wire [N-1:0] parallel_in,     // Parallel input for PIPO, PISO
    output reg [N-1:0] q,               // Parallel output (for SIPO, PIPO)
    output wire serial_out              // Serial output for PISO, SISO
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q <= 0; 
        end else begin
            case (mode_sel)

                2'b00: begin
                    q <= q;
                end

                2'b01: begin
                    if (shift_dir == 0) begin
                        q <= {serial_in, q[N-1:1]};
                    end else begin
                        q <= {q[N-2:0], serial_in};
                    end
                end

                2'b10: begin
                    if (shift_dir == 0) begin
                        q <= {q[0], q[N-1:1]};
                    end else begin
                        q <= {q[N-2:0], q[N-1]};
                    end
                end

                2'b11: begin
                    q <= parallel_in;
                end

                default: q <= q; 
                
            endcase
        end
    end

    assign serial_out = (shift_dir == 0) ? q[0] : q[N-1]; 

endmodule
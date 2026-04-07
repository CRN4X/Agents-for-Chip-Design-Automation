module rc5_enc_16bit(
    input  wire        clock,
    input  wire        reset,
    input  wire        enc_start,
    input  wire [15:0] p,
    output reg  [15:0] c,
    output reg         enc_done
);
    localparam [7:0] S0 = 8'hAB;
    localparam [7:0] S1 = 8'h29;
    localparam [7:0] S2 = 8'h6E;
    localparam [7:0] S3 = 8'hC1;

    reg [1:0] state;
    reg [7:0] a,b;

    function [7:0] rol8(input [7:0] x, input [2:0] sh);
        begin
            rol8 = (x << sh) | (x >> (8-sh));
        end
    endfunction

    always @(posedge clock) begin
        if (!reset) begin
            state <= 2'd0;
            a <= 8'd0;
            b <= 8'd0;
            c <= 16'd0;
            enc_done <= 1'b0;
        end else begin
            enc_done <= 1'b0;
            case (state)
                2'd0: begin
                    if (enc_start) begin
                        a <= p[15:8] + S0;
                        b <= p[7:0] + S1;
                        state <= 2'd1;
                    end
                end
                2'd1: begin
                    a <= rol8(a ^ b, b[2:0]) + S2;
                    state <= 2'd2;
                end
                2'd2: begin
                    b <= rol8(b ^ a, a[2:0]) + S3;
                    state <= 2'd3;
                end
                2'd3: begin
                    c <= {a,b};
                    enc_done <= 1'b1;
                    state <= 2'd0;
                end
            endcase
        end
    end
endmodule

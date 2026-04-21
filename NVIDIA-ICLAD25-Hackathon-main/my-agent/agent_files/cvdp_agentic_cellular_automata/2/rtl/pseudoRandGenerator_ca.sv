`timescale 1ns/1ns

module pseudoRandGenerator_ca (
    input  logic        clock,
    input  logic        reset,
    input  logic [15:0] CA_seed,
    input  logic [1:0]  rule_sel,
    output logic [15:0] CA_out
);

    logic [15:0] next_CA_out;

    function automatic logic compute_next_bit (
        input logic left,
        input logic center,
        input logic right,
        input logic [1:0] rule
    );
        case (rule)
            2'b01: begin
                // Rule 110
                case ({left, center, right})
                    3'b111: compute_next_bit = 1'b0;
                    3'b110: compute_next_bit = 1'b1;
                    3'b101: compute_next_bit = 1'b1;
                    3'b100: compute_next_bit = 1'b0;
                    3'b011: compute_next_bit = 1'b1;
                    3'b010: compute_next_bit = 1'b1;
                    3'b001: compute_next_bit = 1'b1;
                    default: compute_next_bit = 1'b0;
                endcase
            end
            default: begin
                // Rule 30 (default for 2'b00 and other encodings)
                case ({left, center, right})
                    3'b111: compute_next_bit = 1'b0;
                    3'b110: compute_next_bit = 1'b0;
                    3'b101: compute_next_bit = 1'b0;
                    3'b100: compute_next_bit = 1'b1;
                    3'b011: compute_next_bit = 1'b1;
                    3'b010: compute_next_bit = 1'b1;
                    3'b001: compute_next_bit = 1'b1;
                    default: compute_next_bit = 1'b0;
                endcase
            end
        endcase
    endfunction

    always_comb begin
        for (int i = 0; i < 16; i++) begin
            logic left_bit;
            logic right_bit;

            left_bit = (i == 0)  ? CA_out[15] : CA_out[i-1];
            right_bit = (i == 15) ? CA_out[0] : CA_out[i+1];

            next_CA_out[i] = compute_next_bit(left_bit, CA_out[i], right_bit, rule_sel);
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            CA_out <= CA_seed;
        end else begin
            CA_out <= next_CA_out;
        end
    end

endmodule

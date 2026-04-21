`timescale 1ns/1ns

module crypto_accelerator #(
    parameter WIDTH = 8
)(
    input                     clk,
    input                     rst,
    input      [WIDTH-1:0]    candidate_e,
    input      [WIDTH-1:0]    totient,
    input                     start_key_check,
    output logic              key_valid,
    output logic              done_key_check,
    input      [WIDTH-1:0]    plaintext,
    input      [WIDTH-1:0]    modulus,
    output logic [WIDTH-1:0]  ciphertext,
    output logic              done_encryption
);

    localparam ST_IDLE      = 2'd0;
    localparam ST_KEY_CHECK = 2'd1;
    localparam ST_ENCRYPT   = 2'd2;
    localparam ST_DONE      = 2'd3;

    logic [1:0] state;

    logic [WIDTH-1:0] candidate_e_reg;
    logic [WIDTH-1:0] totient_reg;
    logic [WIDTH-1:0] plaintext_reg;
    logic [WIDTH-1:0] modulus_reg;

    logic gcd_go;
    logic [WIDTH-1:0] gcd_out;
    logic gcd_done;

    logic modexp_start;
    logic [WIDTH-1:0] modexp_result;
    logic modexp_done;

    gcd_top_1 #(
        .WIDTH(WIDTH)
    ) u_gcd (
        .clk(clk),
        .rst(rst),
        .A(candidate_e_reg),
        .B(totient_reg),
        .go(gcd_go),
        .OUT(gcd_out),
        .done(gcd_done)
    );

    modular_exponentiation #(
        .WIDTH(WIDTH)
    ) u_modexp (
        .clk(clk),
        .rst(rst),
        .start(modexp_start),
        .base(plaintext_reg),
        .exponent(candidate_e_reg),
        .mod_val(modulus_reg),
        .result(modexp_result),
        .done(modexp_done)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state            <= ST_IDLE;
            candidate_e_reg  <= '0;
            totient_reg      <= '0;
            plaintext_reg    <= '0;
            modulus_reg      <= '0;
            gcd_go           <= 1'b0;
            modexp_start     <= 1'b0;
            key_valid        <= 1'b0;
            done_key_check   <= 1'b0;
            ciphertext       <= '0;
            done_encryption  <= 1'b0;
        end else begin
            gcd_go       <= 1'b0;
            modexp_start <= 1'b0;

            case (state)
                ST_IDLE: begin
                    key_valid       <= 1'b0;
                    done_key_check  <= 1'b0;
                    done_encryption <= 1'b0;
                    ciphertext      <= '0;
                    if (start_key_check) begin
                        candidate_e_reg <= candidate_e;
                        totient_reg     <= totient;
                        plaintext_reg   <= plaintext;
                        modulus_reg     <= modulus;
                        gcd_go          <= 1'b1;
                        state           <= ST_KEY_CHECK;
                    end
                end

                ST_KEY_CHECK: begin
                    if (gcd_done) begin
                        done_key_check <= 1'b1;
                        key_valid      <= (gcd_out == {{(WIDTH-1){1'b0}}, 1'b1});
                        if (gcd_out == {{(WIDTH-1){1'b0}}, 1'b1}) begin
                            modexp_start <= 1'b1;
                            state        <= ST_ENCRYPT;
                        end else begin
                            ciphertext      <= '0;
                            done_encryption <= 1'b1;
                            state           <= ST_DONE;
                        end
                    end
                end

                ST_ENCRYPT: begin
                    if (modexp_done) begin
                        ciphertext      <= modexp_result;
                        done_encryption <= 1'b1;
                        state           <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    if (!start_key_check) begin
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule

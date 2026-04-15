`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// modular_exponentiation module: Computes (base^exponent) mod mod_val using the
// square-and-multiply algorithm.
// This module reuses the modular_multiplier module for multiplication operations.
//-----------------------------------------------------------------------------
module modular_exponentiation #(
    parameter WIDTH = 8
)(
    input                     clk,
    input                     rst,
    input                     start,
    input      [WIDTH-1:0]    base,
    input      [WIDTH-1:0]    exponent,
    input      [WIDTH-1:0]    mod_val,
    output reg [WIDTH-1:0]    result,
    output reg                done
);
    // FSM state definitions.
    localparam STATE_IDLE        = 0;
    localparam STATE_INIT        = 1;
    localparam STATE_CHECK       = 2;
    localparam STATE_WAIT_RESULT = 3;
    localparam STATE_MULT_BASE   = 4;
    localparam STATE_WAIT_BASE   = 5;
    localparam STATE_SHIFT       = 6;
    localparam STATE_DONE        = 7;

    reg [3:0]       state;
    reg [WIDTH-1:0] res_reg;
    reg [WIDTH-1:0] base_reg;
    reg [WIDTH-1:0] exp_reg;

    // Signals for the modular multiplier instance.
    reg mult_start;
    reg [WIDTH-1:0] mult_A, mult_B, mult_mod;
    wire [WIDTH-1:0] mult_result;
    wire mult_done;

    // Instantiate the modular_multiplier.
    modular_multiplier #(
        .WIDTH(WIDTH)
    ) mod_mult_inst (
        .clk(clk),
        .rst(rst),
        .start(mult_start),
        .A(mult_A),
        .B(mult_B),
        .mod_val(mult_mod),
        .result(mult_result),
        .done(mult_done)
    );

    always @(posedge clk) begin
        if(rst) begin
            state      <= STATE_IDLE;
            res_reg    <= 0;
            base_reg   <= 0;
            exp_reg    <= 0;
            result     <= 0;
            done       <= 0;
            mult_start <= 0;
        end else begin
            case(state)
                STATE_IDLE: begin
                    done <= 0;
                    if(start)
                        state <= STATE_INIT;
                end
                STATE_INIT: begin
                    res_reg  <= 1;                // Initialize result to 1.
                    base_reg <= base % mod_val;    // Reduce base modulo mod_val.
                    exp_reg  <= exponent;
                    state    <= STATE_CHECK;
                end
                STATE_CHECK: begin
                    if(exp_reg == 0) begin
                        if(base_reg == 0 & mod_val==1)
                            result <= 0;
                        else
                            result <= res_reg;
                        state  <= STATE_DONE;
                    end else begin
                        if(exp_reg[0] == 1'b1) begin
                            mult_A   <= base_reg;
                            mult_B   <= base_reg;
                            mult_mod <= mod_val;
                            mult_start <= 1;
                            state <= STATE_WAIT_RESULT;
                        end else begin
                            state <= STATE_MULT_BASE;
                        end
                    end
                end
                STATE_WAIT_RESULT: begin
                    mult_start <= 0;
                    if(mult_done) begin
                        res_reg <= mult_result;
                        state <= STATE_MULT_BASE;
                    end
                end
                STATE_MULT_BASE: begin
                    mult_A   <= base_reg;
                    mult_B   <= res_reg;
                    mult_mod <= mod_val;
                    mult_start <= 1;
                    state <= STATE_WAIT_BASE;
                end
                STATE_WAIT_BASE: begin
                    mult_start <= 0;
                    if(mult_done) begin
                        base_reg <= mult_result;
                        state <= STATE_SHIFT;
                    end
                end
                STATE_SHIFT: begin
                    exp_reg <= exp_reg >> 1; // Shift exponent right.
                    state   <= STATE_CHECK;
                end
                STATE_DONE: begin
                    done <= 1;
                    // Remain in DONE state until start is deasserted.
                    if(!start)
                        state <= STATE_IDLE;
                end
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule
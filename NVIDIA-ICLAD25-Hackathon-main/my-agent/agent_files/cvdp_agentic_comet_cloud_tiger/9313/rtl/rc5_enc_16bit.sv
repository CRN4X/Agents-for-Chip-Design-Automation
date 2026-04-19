module rc5_enc_16bit (
    input  wire        clock,
    input  wire        reset,      // Synchronous active-low reset
    input  wire        enc_start,
    input  wire [15:0] p,
    output reg  [15:0] c,
    output reg         enc_done
);

    localparam [7:0] S0 = 8'hAB;
    localparam [7:0] S1 = 8'h29;
    localparam [7:0] S2 = 8'h6E;
    localparam [7:0] S3 = 8'hC1;

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_MSB  = 2'd1;
    localparam [1:0] ST_LSB  = 2'd2;
    localparam [1:0] ST_OUT  = 2'd3;

    reg [1:0] state;
    reg [7:0] a_reg;
    reg [7:0] b_reg;

    function automatic [7:0] rotl8;
        input [7:0] val;
        input [2:0] shamt;
        begin
            if (shamt == 3'd0) begin
                rotl8 = val;
            end else begin
                rotl8 = (val << shamt) | (val >> (4'd8 - {1'b0, shamt}));
            end
        end
    endfunction

    always_ff @(posedge clock) begin
        if (!reset) begin
            state    <= ST_IDLE;
            a_reg    <= 8'h00;
            b_reg    <= 8'h00;
            c        <= 16'h0000;
            enc_done <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    enc_done <= 1'b0;
                    if (enc_start) begin
                        // Initial addition stage
                        a_reg <= p[15:8] + S0;
                        b_reg <= p[7:0] + S1;
                        state <= ST_MSB;
                    end
                end

                ST_MSB: begin
                    // Compute updated MSB byte
                    a_reg <= rotl8(a_reg ^ b_reg, b_reg[2:0]) + S2;
                    state <= ST_LSB;
                end

                ST_LSB: begin
                    // Compute updated LSB byte using new A value (nonblocking RHS uses old a_reg)
                    b_reg <= rotl8(b_reg ^ a_reg, a_reg[2:0]) + S3;
                    state <= ST_OUT;
                end

                ST_OUT: begin
                    c        <= {a_reg, b_reg};
                    enc_done <= 1'b1;
                    if (!enc_start) begin
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

module cipher (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        start,
    input  logic [31:0] data_in,
    input  logic [15:0] key,
    output logic [31:0] data_out,
    output logic        done
);

    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        ROUND  = 2'b01,
        FINISH = 2'b10
    } state_t;

    state_t       state;
    logic [15:0]  left_reg;
    logic [15:0]  right_reg;
    logic [15:0]  round_key;
    logic [3:0]   round_ctr;

    function automatic logic [15:0] f_function(
        input logic [15:0] right_half,
        input logic [15:0] subkey
    );
        logic [15:0] mixed;
        logic [15:0] rotl3;
        logic [15:0] rotr2;
        begin
            mixed = right_half ^ subkey;
            rotl3 = {mixed[12:0], mixed[15:13]};
            rotr2 = {mixed[1:0], mixed[15:2]};
            f_function = (rotl3 + rotr2) ^ subkey;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            left_reg   <= 16'h0000;
            right_reg  <= 16'h0000;
            round_key  <= 16'h0000;
            round_ctr  <= 4'h0;
            data_out   <= 32'h00000000;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        left_reg  <= data_in[31:16];
                        right_reg <= data_in[15:0];
                        round_key <= key;
                        round_ctr <= 4'd0;
                        state     <= ROUND;
                    end
                end

                ROUND: begin
                    left_reg  <= right_reg;
                    right_reg <= left_reg ^ f_function(right_reg, round_key);

                    if (round_ctr == 4'd7) begin
                        state <= FINISH;
                    end else begin
                        round_ctr <= round_ctr + 4'd1;
                        round_key <= {round_key[14:0], round_key[15]} ^ {12'h000, (round_ctr + 4'd1)};
                    end
                end

                FINISH: begin
                    data_out <= {right_reg, left_reg};
                    done     <= 1'b1;
                    state    <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

`timescale 1ns/1ns

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
    logic [15:0]  left;
    logic [15:0]  right;
    logic [15:0]  round_key;
    logic [3:0]   round_cnt;
    logic [15:0]  f_val;
    logic [15:0]  key_rot;

    function automatic logic [15:0] f_function (
        input logic [15:0] r_in,
        input logic [15:0] k_in
    );
        logic [15:0] x;
        logic [15:0] rot_l;
        logic [15:0] rot_r;
        begin
            x = r_in ^ k_in;
            rot_l = {x[12:0], x[15:13]};
            rot_r = {x[4:0], x[15:5]};
            f_function = (rot_l + rot_r + k_in) & 16'hFFFF;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            left       <= 16'h0000;
            right      <= 16'h0000;
            round_key  <= 16'h0000;
            round_cnt  <= 4'd0;
            data_out   <= 32'h00000000;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    round_cnt <= 4'd0;
                    if (start) begin
                        left      <= data_in[31:16];
                        right     <= data_in[15:0];
                        round_key <= key;
                        state     <= ROUND;
                    end
                end

                ROUND: begin
                    f_val <= f_function(right, round_key);
                    left  <= right;
                    right <= left ^ f_function(right, round_key);

                    key_rot   <= {round_key[14:0], round_key[15]};
                    round_key <= {round_key[14:0], round_key[15]} ^ {12'h000, round_cnt};

                    if (round_cnt == 4'd7) begin
                        state <= FINISH;
                    end else begin
                        round_cnt <= round_cnt + 4'd1;
                    end
                end

                FINISH: begin
                    data_out <= {right, left};
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

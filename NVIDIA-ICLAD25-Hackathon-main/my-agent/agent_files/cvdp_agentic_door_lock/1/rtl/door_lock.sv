`timescale 1ns/1ns

module door_lock #(
    parameter PASSWORD_LENGTH = 4,
    parameter MAX_TRIALS = 3
) (
    input  logic                         clk,
    input  logic                         srst,
    input  logic [3:0]                   key_input,
    input  logic                         key_valid,
    input  logic                         confirm,
    input  logic                         admin_override,
    input  logic                         admin_set_mode,
    input  logic [PASSWORD_LENGTH*4-1:0] new_password,
    input  logic                         new_password_valid,
    output logic                         door_unlock,
    output logic                         lockout
);

    localparam int PASS_W = PASSWORD_LENGTH * 4;
    localparam int CNT_W  = (PASSWORD_LENGTH > 1) ? $clog2(PASSWORD_LENGTH + 1) : 1;
    localparam int TRY_W  = (MAX_TRIALS > 1) ? $clog2(MAX_TRIALS + 1) : 1;

    logic [PASS_W-1:0] stored_password;
    logic [PASS_W-1:0] entered_password;
    logic [CNT_W-1:0]  entered_count;
    logic [TRY_W-1:0]  fail_count;

    always_ff @(posedge clk) begin
        if (srst) begin
            stored_password  <= {{(PASS_W-4){1'b0}}, 4'h1};
            entered_password <= '0;
            entered_count    <= '0;
            fail_count       <= '0;
            door_unlock      <= 1'b0;
            lockout          <= 1'b0;
        end else begin
            if ((admin_override === 1'b1) && (admin_set_mode !== 1'b1)) begin
                door_unlock      <= 1'b1;
                lockout          <= 1'b0;
                fail_count       <= '0;
                entered_password <= '0;
                entered_count    <= '0;
            end else if (lockout) begin
                entered_password <= '0;
                entered_count    <= '0;
            end else if ((admin_override === 1'b1) && (admin_set_mode === 1'b1)) begin
                if (new_password_valid === 1'b1) begin
                    stored_password <= new_password;
                end
            end else begin
                if ((key_valid === 1'b1) && (key_input <= 4'd9) && (entered_count < PASSWORD_LENGTH)) begin
                    entered_password <= (entered_password << 4) | key_input;
                    entered_count    <= entered_count + 1'b1;
                end

                if (confirm === 1'b1) begin
                    if (entered_count == PASSWORD_LENGTH) begin
                        if (entered_password == stored_password) begin
                            door_unlock <= 1'b1;
                            fail_count  <= '0;
                        end else begin
                            door_unlock <= 1'b0;
                            if (fail_count + 1'b1 >= MAX_TRIALS) begin
                                lockout <= 1'b1;
                            end
                            fail_count <= fail_count + 1'b1;
                        end
                    end else begin
                        door_unlock <= 1'b0;
                        if (fail_count + 1'b1 >= MAX_TRIALS) begin
                            lockout <= 1'b1;
                        end
                        fail_count <= fail_count + 1'b1;
                    end

                    entered_password <= '0;
                    entered_count    <= '0;
                end
            end
        end
    end

endmodule

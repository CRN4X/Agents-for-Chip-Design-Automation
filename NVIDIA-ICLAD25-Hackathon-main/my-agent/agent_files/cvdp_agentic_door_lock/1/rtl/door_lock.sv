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

    localparam int ENTRY_CNT_W = (PASSWORD_LENGTH > 1) ? $clog2(PASSWORD_LENGTH + 1) : 1;
    localparam int FAIL_CNT_W  = (MAX_TRIALS > 1) ? $clog2(MAX_TRIALS + 1) : 1;

    logic [PASSWORD_LENGTH*4-1:0] stored_password;
    logic [PASSWORD_LENGTH*4-1:0] entered_password;
    logic [ENTRY_CNT_W-1:0]       entry_count;
    logic [FAIL_CNT_W-1:0]        fail_count;

    always_ff @(posedge clk) begin
        if (srst) begin
            stored_password <= '0;
            stored_password[3:0] <= 4'h1;
            entered_password <= '0;
            entry_count <= '0;
            fail_count <= '0;
            door_unlock <= 1'b0;
            lockout <= 1'b0;
        end else begin
            if (admin_override) begin
                if (admin_set_mode) begin
                    if (new_password_valid) begin
                        stored_password <= new_password;
                    end
                end else begin
                    door_unlock <= 1'b1;
                    fail_count <= '0;
                    lockout <= 1'b0;
                    entered_password <= '0;
                    entry_count <= '0;
                end
            end else if (lockout) begin
                // Stay locked out until admin override or reset.
            end else begin
                if (key_valid && (key_input <= 4'd9) && (entry_count < PASSWORD_LENGTH)) begin
                    entered_password <= (entered_password << 4) | key_input;
                    entry_count <= entry_count + 1'b1;
                end

                if (confirm) begin
                    if ((entry_count == PASSWORD_LENGTH) && (entered_password == stored_password)) begin
                        door_unlock <= 1'b1;
                        fail_count <= '0;
                    end else begin
                        door_unlock <= 1'b0;
                        if ((fail_count + 1'b1) >= MAX_TRIALS) begin
                            fail_count <= MAX_TRIALS[FAIL_CNT_W-1:0];
                            lockout <= 1'b1;
                        end else begin
                            fail_count <= fail_count + 1'b1;
                        end
                    end

                    entered_password <= '0;
                    entry_count <= '0;
                end
            end
        end
    end

endmodule

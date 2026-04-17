module modulator (
    input logic clk,
    input logic rst,
    input logic enable,
    output logic [15:0] mod_signal
);
    logic [15:0] counter;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) counter <= 0;
        else if (enable) counter <= counter + 1;
    end

    assign mod_signal = counter;
endmodule
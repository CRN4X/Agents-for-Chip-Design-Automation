module soft_clipper #(
    parameter WIDTH = 16
)(
    input logic signed [WIDTH-1:0] in_signal,
    output logic signed [WIDTH-1:0] out_signal
);
    always_comb begin
        if (in_signal > 20480)
            out_signal = 20480;
        else if (in_signal < -20480)
            out_signal = -20480;
        else
            out_signal = in_signal - ((in_signal * in_signal) >>> 10);
    end
endmodule
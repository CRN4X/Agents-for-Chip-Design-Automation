module blake2s_core_reset_and_ready_sanity_check (
                    input wire            clk,
                    input wire            reset_n,

                    input wire            init,
                    input wire            update,
                    input wire            finish,

                    input wire [511 : 0]  block,
                    input wire [6 : 0]    blocklen,

                    output wire [255 : 0] digest,
                    output wire           ready
                  );

    blake2s_core dut(
        .clk(clk),
        .reset_n(reset_n),
        .init(init),
        .update(update),
        .finish(finish),
        .block(block),
        .blocklen(blocklen),
        .digest(digest),
        .ready(ready)
    );

endmodule : blake2s_core_reset_and_ready_sanity_check
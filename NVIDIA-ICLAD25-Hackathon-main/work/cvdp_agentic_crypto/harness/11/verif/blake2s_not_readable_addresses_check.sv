module blake2s_not_readable_addresses_check(
               input wire           clk,
               input wire           reset_n,

               input wire           cs,
               input wire           we,

               input wire  [7 : 0]  address,
               input wire  [31 : 0] write_data,
               output wire [31 : 0] read_data
              );

    blake2s dut(
        .clk(clk),
        .reset_n(reset_n),
        .cs(cs),
        .we(we),
        .address(address),
        .write_data(write_data),
        .read_data(read_data)
    );

endmodule : blake2s_not_readable_addresses_check
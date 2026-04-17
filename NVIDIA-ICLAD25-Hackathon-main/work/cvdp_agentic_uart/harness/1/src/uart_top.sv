module uart_top (
                   /* Clock and Reset */
                   input  logic         clk            ,        // Clock
                   input  logic         rstn           ,        // Active-low Asynchronous Reset   

                   /* Serial Interface */
                   output logic         o_tx           ,        // Serial data out, TX
                   input  logic         i_rx           ,        // Serial data in, RX              
                   
                   /* Control Signals */    
                   input  logic [15:0]  i_baudrate     ,        // Baud rate
                   input  logic [1:0]   i_parity_mode  ,        // Parity mode
                   input  logic         i_frame_mode   ,        // Frame mode 
                   input  logic         i_lpbk_mode_en ,        // Loopback mode enable
                   input  logic         i_tx_break_en  ,        // Enable to send break frame on TX
                   input  logic         i_tx_en        ,        // UART TX (Transmitter) enable
                   input  logic         i_rx_en        ,        // UART RX (Receiver) enable 
                   input  logic         i_tx_rst       ,        // UART TX reset
                   input  logic         i_rx_rst       ,        // UART RX reset                
                   
                   /* UART TX Data Interface */    
                   input  logic [7:0]   i_data         ,        // Parallel data input
                   input  logic         i_data_valid   ,        // Input data valid
                   output logic         o_ready        ,        // Ready signal from UART TX 
                   
                   /* UART RX Data Interface */ 
                   output logic [7:0]   o_data         ,        // Parallel data output
                   output logic         o_data_valid   ,        // Output data valid
                   input  logic         i_ready        ,        // Ready signal to UART RX
                   
                   /* Status Signals */   
                   output logic         o_tx_state     ,        // State of UART TX (enabled/disabled)
                   output logic         o_rx_state     ,        // State of UART RX (enabled/disabled)
                   output logic         o_rx_break     ,        // Flags break frame received on RX
                   output logic         o_parity_err   ,        // Parity error flag
                   output logic         o_frame_err             // Frame error flag                                            
);


//   Internal Registers/Signals

// Connection between Baud Generator & UART TX 
logic tx_baud_clk ;        // Baud clock pulse from Baud Generator to UART TX
logic tx_ready    ;        // TX ready

// Connection between Baud Generator & UART RX 
logic rx_baud_clk ;        // Baud clock pulse from Baud Generator to UART RX
logic rx_ready    ;        // RX ready
logic rx_en       ;        // RX enable

// Other signals
logic tx          ;        // TX data to Serial I/F
logic rx          ;        // RX data from Serial I/F or loopback
logic irx_sync    ;        // Serial data input synchronized to the core-clock domain
logic tx_rst_sync ;        // Synchronized reset to TX
logic rx_rst_sync ;        // Synchronized reset to RX


//   Sub-modules Instantations

// Baud Generator
baud_gen inst_baud_gen    (
                        .clk           ( clk  )                  ,
                        .tx_rst        ( tx_rst_sync )           ,
                        .rx_rst        ( rx_rst_sync )           ,
         
                        .i_baudrate    ( i_baudrate  )           ,
                        .i_tx_en       ( i_tx_en     )           ,
                        .i_rx_en       ( i_rx_en     )           ,    
                        .i_tx_ready    ( tx_ready    )           ,    
                        .i_rx_ready    ( rx_ready    )           , 
                        .o_rx_en       ( rx_en       )           ,  
         
                        .o_tx_baud_clk ( tx_baud_clk )           ,
                        .o_rx_baud_clk ( rx_baud_clk )           ,

                        .o_tx_state    ( o_tx_state )            ,
                        .o_rx_state    ( o_rx_state )
                     ) ;

// UART TX   
uart_tx inst_uart_tx      (
                        .clk           ( clk            )        ,
                        .rstn          ( tx_rst_sync    )        , 
        
                        .i_baud_clk    ( tx_baud_clk    )        ,

                        .i_parity_mode ( i_parity_mode  )        ,
                        .i_frame_mode  ( i_frame_mode   )        ,
                        .i_break_en    ( i_tx_break_en  )        ,

                        .i_data        ( i_data         )        ,
                        .i_data_valid  ( i_data_valid   )        ,
                        .o_ready       ( tx_ready       )        ,

                        .o_tx          ( tx             )     
                     ) ;

// UART RX   
uart_rx inst_uart_rx      (
                        .clk           ( clk            )        ,
                        .rstn          ( rx_rst_sync    )        , 
        
                        .i_baud_clk    ( rx_baud_clk    )        ,
                        
                        .i_rx_en       ( rx_en          )        ,
                        .i_parity_mode ( i_parity_mode  )        ,
                        .i_frame_mode  ( i_frame_mode   )        ,
                        
                        .i_rx          ( irx_sync       )        ,

                        .o_data        ( o_data         )        ,
                        .o_data_valid  ( o_data_valid   )        ,
                        .i_ready       ( i_ready        )        ,
                        
                        .o_rx_ready    ( rx_ready       )        ,
                        .o_break       ( o_rx_break     )        ,
                        .o_parity_err  ( o_parity_err   )        ,
                        .o_frame_err   ( o_frame_err    )   
                     ) ;

// RX serial data synchronizer for CDC
cdc_sync inst_rx_sync     (
                        .clk         ( clk      ) ,
                        .rstn        ( rstn     ) ,
                        .i_sig       ( rx       ) ,
                        .o_sig_sync  ( irx_sync )
                     ) ;

// Reset synchronizer for TX
areset_sync inst_tx_rst_sync (
                         .clk         (clk)              ,
                         .i_rst_async (~i_tx_rst & rstn) ,
                         .o_rst_sync  (tx_rst_sync)

                      ) ;

// Reset synchronizer for RX
areset_sync inst_rx_rst_sync (
                         .clk         (clk)              ,
                         .i_rst_async (~i_rx_rst & rstn) ,
                         .o_rst_sync  (rx_rst_sync)

                      ) ;

// Loopback is expected to be switched after disabling TX and RX to avoid glitches/broken frames...
assign rx = i_lpbk_mode_en?  tx : i_rx ;

// Outputs
assign o_tx    = tx       ;
assign o_ready = tx_ready ;

endmodule
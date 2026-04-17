module areset_sync #(   
   // Configurable parameters   
   parameter STAGES  = 2    ,        // No. of flops in the synchronizer chain, min. 2
   parameter RST_POL = 1'b0          // Reset polarity
)

(
   input  logic clk         ,        // Clock @ destination clock domain   
   input  logic i_rst_async ,        // Asynchronous Reset in
   output logic o_rst_sync           // Asynchronous Reset with de-assertion synchronized
) ;

logic reset ;
assign reset = i_rst_async ^ RST_POL ;

(* ASYNC_REG = "TRUE" *)
logic [STAGES-1:0] sync_ff ;

// Synchronizing logic
always @(posedge clk or negedge reset) begin
   
   if (!reset) begin
      sync_ff <= {STAGES{RST_POL}} ;
   end
   else begin
      sync_ff <= {sync_ff[STAGES-2:0], ~RST_POL} ;     
   end  

end

// Synchronized reset
assign o_rst_sync = sync_ff[STAGES-1] ;

endmodule
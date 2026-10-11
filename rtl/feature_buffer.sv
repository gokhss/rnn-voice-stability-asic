module feature_buffer #(parameter integer INPUTS=8)(
 input logic clk,rst_n,capture,
 input logic [INPUTS*16-1:0] features,
 output logic [INPUTS*16-1:0] buffered
);
 always_ff @(posedge clk) begin
   if (!rst_n) buffered <= '0;
   else if (capture) buffered <= features;
 end
endmodule

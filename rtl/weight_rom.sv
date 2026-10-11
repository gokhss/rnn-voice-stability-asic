// Historical module name retained; now a runtime-loaded INT8 coefficient store.
module weight_rom #(parameter integer INPUTS=8,HIDDEN=16,
 parameter integer M=3*HIDDEN*(INPUTS+HIDDEN)+HIDDEN,B=3*HIDDEN+1)(
 input logic clk,write_enable,
 input logic [$clog2(M+B)-1:0] write_index,
 input logic [31:0] write_data,
 input logic [$clog2(M)-1:0] weight_address,
 input logic [$clog2(B)-1:0] bias_address,
 output logic signed [7:0] weight,
 output logic signed [31:0] bias
);
 logic signed [7:0] weights[0:M-1];
 logic signed [31:0] biases[0:B-1];
 // No reset on memory: top-level model_valid prevents reading incomplete images.
 always_ff @(posedge clk) if(write_enable) begin
  if({{(32-$clog2(M+B)){1'b0}},write_index}<M) weights[write_index]<=write_data[7:0];
  else if({{(32-$clog2(M+B)){1'b0}},write_index}<M+B) biases[{{(32-$clog2(M+B)){1'b0}},write_index}-M]<=write_data;
 end
 always_comb begin
  weight='0; bias='0;
  if({{(32-$clog2(M)){1'b0}},weight_address}<M) weight=weights[weight_address];
  if({{(32-$clog2(B)){1'b0}},bias_address}<B) bias=biases[bias_address];
 end
endmodule

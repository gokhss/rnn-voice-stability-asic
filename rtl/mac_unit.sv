// One shared signed multiplier. Matrix products F19, elementwise products F24.
module mac_unit #(parameter integer ACC_W=40)(
 input logic clk,rst_n,clear,accumulate,
 input logic signed [15:0] a,b,
 input logic signed [31:0] bias,
 input logic [3:0] shift,
 output logic signed [15:0] result,
 output logic saturated
);
 logic signed [ACC_W-1:0] acc;
 logic signed [31:0] product;
 logic signed [ACC_W:0] wide,magnitude,rounded_value,half;
 // Operand isolation: idle cycles do not toggle the multiplier.
 assign product=accumulate ? a*b : 32'sd0;
 always_ff @(posedge clk) begin
  if(!rst_n) acc<='0;
  else if(clear) acc<={{(ACC_W-32){bias[31]}},bias};
  else if(accumulate) acc<=acc+{{(ACC_W-32){product[31]}},product};
 end
 always_comb begin
  wide={acc[ACC_W-1],acc};
  magnitude=wide<0 ? -wide : wide;
  half=shift==0 ? '0 : ({{ACC_W{1'b0}},1'b1} << (shift-1'b1));
  rounded_value=(magnitude+half) >>> shift;
  if(wide<0) rounded_value=-rounded_value;
  saturated=1'b0;
  if(rounded_value>32767) begin result=16'sh7fff; saturated=1'b1; end
  else if(rounded_value< -32768) begin result=16'sh8000; saturated=1'b1; end
  else result=rounded_value[15:0];
 end
endmodule

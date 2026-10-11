`timescale 1ns/1ps
// Arithmetic/activation regression; cell state/gates compared in top integration bench.
module tb_gru_cell;
 logic clk=0; always #5 clk=~clk;
 logic rst_n=0,clear=0,accumulate=0,saturated;
 logic signed [15:0] a=0,b=0,result,ax=0,sy,ty;
 logic signed [31:0] bias=0;
 logic [3:0] shift=12;
 logic [31:0] activations[0:65535];
 string directory;
 integer j;
 mac_unit dut(.*);
 sigmoid_lut sig(.x(ax),.y(sy)); tanh_lut th(.x(ax),.y(ty));
 task automatic check_mac(input integer aa,bb,bi,sh,num,expected,input bit sat_expected);
  begin
   @(negedge clk);clear=1;accumulate=0;bias=32'(bi);shift=4'(sh);
   @(negedge clk);clear=0;accumulate=1;a=16'(aa);b=16'(bb);
   repeat(num) @(negedge clk);
   accumulate=0;#1;
   if(result!==16'(expected) || saturated!==sat_expected) $fatal(1,"MAC got %0d sat=%0d expected %0d sat=%0d",result,saturated,expected,sat_expected);
  end
 endtask
 initial begin
  if(!$value$plusargs("DATA=%s",directory)) directory="build/hardware";
  $readmemh({directory,"/activations.mem"},activations);
  repeat(2) @(negedge clk);rst_n=1;
  check_mac(1,2048,0,12,1,1,0);check_mac(-1,2048,0,12,1,-1,0);
  check_mac(1,64,0,7,1,1,0);check_mac(-1,64,0,7,1,-1,0);
  check_mac(1,63,0,7,1,0,0);check_mac(-1,63,0,7,1,0,0);
  check_mac(32767,32767,0,12,1,32767,1);check_mac(-32768,32767,0,12,1,-32768,1);
  check_mac(-32768,-128,2147483647,7,48,32767,1);
  check_mac(-32768,127,-2147483647-1,7,48,-32768,1);
  check_mac(0,0,-128,7,1,-1,0);
  for(j=0;j<65536;j=j+1) begin
   ax=16'(j-32768);#1;
   if({sy,ty}!==activations[j]) $fatal(1,"activation code=%0d got=%h expected=%h",j-32768,{sy,ty},activations[j]);
  end
  $display("PASS: MAC ties, widths, saturation, 48-term bounds; 65536 sigmoid/tanh codes");$finish;
 end
 initial begin #200000; $fatal(1,"arithmetic watchdog");end
endmodule

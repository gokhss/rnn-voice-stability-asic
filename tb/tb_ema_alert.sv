`timescale 1ns/1ps
module tb_ema_alert;
 logic clk=0;always #5 clk=~clk;
 logic rst_n=0,valid=0,average_valid,initialized;
 logic [15:0] score=0,average,next_average;
 logic [3:0] ema_shift=0;
 integer k,j,ref_avg,delta,step_v,v;
 moving_average #(.EMA_MODE(1)) dut(.clk(clk),.rst_n(rst_n),.valid(valid),.score(score),.window_length(5'd0),.*);
 initial begin
  for(k=0;k<=8;k=k+1)begin
   @(negedge clk);rst_n=0;valid=0;
   @(negedge clk);rst_n=1;ema_shift=4'(k);ref_avg=0;
   for(j=0;j<100;j=j+1)begin
    @(negedge clk);valid=1;v=(j%3==0)?65535:((j%3==1)?0:32768);score=16'(v);
    if(j==0)ref_avg=v;
    else begin
     delta=v-ref_avg;
     step_v=k==0 ? (delta<0 ? -delta:delta) : (((delta<0 ? -delta:delta)+(1<<(k-1)))>>k);
     ref_avg=ref_avg+(delta<0 ? -step_v:step_v);
    end
    @(posedge clk);#1;
    if(average!==16'(ref_avg) || !initialized || !average_valid)$fatal(1,"EMA K=%0d frame=%0d",k,j);
    @(negedge clk);valid=0;score=~score;
    @(posedge clk);#1;if(average!==16'(ref_avg) || average_valid)$fatal(1,"EMA invalid changes history");
   end
  end
  $display("PASS: EMA K=0..8, 900 updates, init, signed rounding, idle hold");$finish;
 end
 initial begin #100000; $fatal(1,"EMA watchdog");end
endmodule

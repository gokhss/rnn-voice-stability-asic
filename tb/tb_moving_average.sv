`timescale 1ns/1ps
module tb_moving_average;
 logic clk=0; always #10 clk=~clk;
 logic rst_n=0,valid=0,average_valid,initialized;
 logic [15:0] score=0,average;
 logic [4:0] window_length=16;
 logic [3:0] ema_shift=4; logic [15:0] next_average;
 integer values[0:15];
 integer count=0,ref_window=0,i,j,w,sum,expected;
 moving_average dut(.*);
 task sample(input integer value,win,accept_sample);
   begin
     @(negedge clk); score=16'(value); window_length=5'(win); valid=1'(accept_sample);
     w=win<1 ? 1 : (win>16 ? 16 : win);
     if(w!=ref_window) begin count=0; ref_window=w; end
     if(accept_sample!=0) begin
       if(count==w) begin
         for(j=0;j<15;j=j+1) values[j]=values[j+1];
         count=count-1;
       end
       values[count]=value; count=count+1;
     end
     sum=0; for(j=0;j<count;j=j+1) sum=sum+values[j];
     expected=count==0 ? 0 : sum/count;
     @(posedge clk); #1;
     if(average!==16'(expected) || average_valid!==1'(accept_sample) || initialized!==1'(count!=0))
       $fatal(1,"average value %d expected %d window %d count %d",average,expected,w,count);
   end
 endtask
 initial begin
   $dumpfile("waveforms/average.vcd"); $dumpvars(0,tb_moving_average);
   repeat(2) @(posedge clk);
   #1; if(average!==0 || initialized || average_valid) $fatal(1,"average reset");
   @(negedge clk); rst_n=1;
   for(i=0;i<64;i=i+1) sample(i%2 ? 65535 : 0,16,1);
   sample(12345,16,0); // invalid does not enter history
   sample(65535,1,1); sample(0,0,1);
   for(i=0;i<20;i=i+1) sample(i*100,7,1);
   sample(0,31,0); sample(65535,31,1);
   $display("PASS: moving average startup, wrap, reconfiguration, invalid, endpoints"); $finish;
 end
 initial begin #200000; $fatal(1,"average watchdog"); end
endmodule

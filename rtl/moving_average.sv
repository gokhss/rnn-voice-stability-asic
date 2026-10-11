module moving_average #(parameter integer MAX_WINDOW=16, parameter integer EMA_MODE=0,
 parameter integer WIN_W=(MAX_WINDOW<2 ? 1 : $clog2(MAX_WINDOW+1)))(
 input logic clk,rst_n,valid,
 input logic [3:0] ema_shift,
 output logic [15:0] next_average,
 input logic [15:0] score,
 // Compatibility-only finite-window input is absent from the synthesized EMA branch.
 /* verilator lint_off UNUSEDSIGNAL */
 input logic [WIN_W-1:0] window_length,
 /* verilator lint_on UNUSEDSIGNAL */
 output logic [15:0] average,
 output logic average_valid,initialized
);
 generate if(EMA_MODE!=0) begin: ema
 logic signed [17:0] delta,mag,step_value,updated;
 always_comb begin
  delta=$signed({2'b00,score})-$signed({2'b00,average});
  mag=delta<0 ? -delta : delta;
  step_value=ema_shift==0 ? mag : (mag+(18'sd1<<(ema_shift-1'b1)))>>>ema_shift;
  if(delta<0) step_value=-step_value;
  updated=$signed({2'b00,average})+step_value;
  if(!initialized) next_average=score;
  else if(updated<0) next_average=0;
  else if(updated>65535) next_average=65535;
  else next_average=updated[15:0];
 end
 always_ff @(posedge clk) begin
  if(!rst_n) begin average<=0; initialized<=0; average_valid<=0; end
  else begin
   average_valid<=valid;
   if(valid) begin average<=next_average; initialized<=1; end
  end
 end
 end else begin: legacy_window
 assign next_average=average;
 localparam integer SUM_W=16+$clog2(MAX_WINDOW+1);
 logic [15:0] history[0:MAX_WINDOW-1];
 logic [SUM_W-1:0] sum,new_sum;
 integer pointer,count,window_reg,effective_window,new_count;
 logic [31:0] quotient;
 assign quotient=new_sum/new_count;
 always_comb begin
   effective_window=window_length;
   if(effective_window<1) effective_window=1;
   if(effective_window>MAX_WINDOW) effective_window=MAX_WINDOW;
   new_sum=sum+{{(SUM_W-16){1'b0}},score};
   if(count==effective_window) new_sum=new_sum-history[pointer];
   new_count=count<effective_window ? count+1 : count;
 end
 always_ff @(posedge clk) begin
   if(!rst_n) begin
     sum<=0; pointer<=0; count<=0; window_reg<=0;
     average<=0; average_valid<=0; initialized<=0;
   end else begin
     average_valid<=0;
     if(effective_window!=window_reg) begin
       window_reg<=effective_window;
       sum<=0; count<=0; pointer<=0; average<=0; initialized<=0;
       if(valid) begin
         history[0]<=score; sum<=score; count<=1;
         pointer<=effective_window==1 ? 0 : 1;
         average<=score; average_valid<=1; initialized<=1;
       end
     end else if(valid) begin
       history[pointer]<=score; sum<=new_sum; count<=new_count;
       pointer<=pointer==effective_window-1 ? 0 : pointer+1;
       average<=quotient[15:0]; average_valid<=1; initialized<=1;
     end
   end
 end
 end endgenerate
endmodule

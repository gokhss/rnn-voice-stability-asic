module alert_controller(
 input logic clk,rst_n,valid,
 input logic [15:0] average,threshold,recovery_threshold,
 output logic alert,
 output logic assert_event,recover_event
);
 assign assert_event=valid && !alert && average<threshold;
 assign recover_event=valid && alert && average>recovery_threshold;
 always_ff @(posedge clk) begin
  if(!rst_n) alert<=0;
  else if(assert_event) alert<=1;
  else if(recover_event) alert<=0;
 end
endmodule

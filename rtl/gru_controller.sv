module gru_controller #(parameter integer INPUTS=8,HIDDEN=16,
 parameter integer NW=$clog2(HIDDEN),TW=$clog2(INPUTS+HIDDEN))(
 input logic clk,rst_n,start,
 output logic busy,done,
 output logic [3:0] stage,
 output logic [1:0] phase,
 output logic [NW-1:0] neuron,
 output logic [TW-1:0] term
);
 localparam [3:0] IDLE=0,INIT=1,DOT=2,ACT=3,QINIT=4,QMUL=5,QSTORE=6,
 BINIT=7,BOLD=8,BNEW=9,BSTORE=10,COMMIT=11,OINIT=12,ODOT=13,OACT=14,DONE=15;
 assign busy=stage!=IDLE;
 assign done=stage==DONE;
 always_ff @(posedge clk) begin
  if(!rst_n) begin stage<=IDLE; phase<=0; neuron<=0; term<=0; end
  else case(stage)
   IDLE:if(start) begin stage<=INIT; phase<=0; neuron<=0; term<=0; end
   INIT:begin stage<=DOT; term<=0; end
   DOT:if({{(32-TW){1'b0}},term}==INPUTS+HIDDEN-1) stage<=ACT; else term<=term+1'b1;
   ACT:if({{(32-NW){1'b0}},neuron}!=HIDDEN-1) begin neuron<=neuron+1'b1; stage<=INIT; end
    else begin
     neuron<=0;
     if(phase==0) begin phase<=1; stage<=INIT; end
     else if(phase==1) stage<=QINIT;
     else stage<=BINIT;
    end
   QINIT:stage<=QMUL;
   QMUL:stage<=QSTORE;
   QSTORE:if({{(32-NW){1'b0}},neuron}==HIDDEN-1) begin neuron<=0; phase<=2; stage<=INIT; end
    else begin neuron<=neuron+1'b1; stage<=QINIT; end
   BINIT:stage<=BOLD;
   BOLD:stage<=BNEW;
   BNEW:stage<=BSTORE;
   BSTORE:if({{(32-NW){1'b0}},neuron}==HIDDEN-1) stage<=COMMIT;
    else begin neuron<=neuron+1'b1; stage<=BINIT; end
   COMMIT:begin stage<=OINIT; phase<=3; term<=0; end
   OINIT:stage<=ODOT;
   ODOT:if({{(32-TW){1'b0}},term}==HIDDEN-1) stage<=OACT; else term<=term+1'b1;
   OACT:stage<=DONE;
   DONE:stage<=IDLE;
   default:stage<=IDLE;
  endcase
 end
endmodule

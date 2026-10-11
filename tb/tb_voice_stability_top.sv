`timescale 1ns/1ps
module tb_voice_stability_top;
 parameter integer INPUTS=8,HIDDEN=16;
 localparam integer M=3*HIDDEN*(INPUTS+HIDDEN)+HIDDEN,B=3*HIDDEN+1,VW=16*INPUTS+80*HIDDEN+56;
 logic clk=0; always #5 clk=~clk;
 logic rst_n=0,enable=1,frame_valid=0,frame_ready;
 logic [INPUTS*16-1:0] features=0;
 logic [15:0] stability_score_out,running_average;
 logic score_valid,average_valid,degradation_alert,busy,irq;
 logic cfg_valid=0,cfg_write=0,cfg_ready,cfg_error;
 logic [7:0] cfg_addr=0;
 logic [31:0] cfg_wdata=0,cfg_rdata;
 logic [31:0] weights[0:M+B-1];
 logic [VW-1:0] vectors[0:359999];
 logic [HIDDEN*16-1:0] ez,er,eq,en,eh;
 logic [15:0] old_score,old_average;
 integer frames=256,i,j,cycles=0,begin_cycle,latency,min_latency=100000,max_latency=0;
 integer accepted_seen,done_seen;
 bit checking=0;
 string directory;
 voice_stability_top #(.INPUTS(INPUTS),.HIDDEN(HIDDEN)) dut(.*);
 always @(posedge clk) cycles<=cycles+1;
 // First divergence is reported at each gate, before later recurrence can mask it.
 always @(negedge clk) if(checking && dut.cell_inst.stage==3) begin
  case(dut.cell_inst.phase)
   0:if(dut.cell_inst.sy!==ez[int'(dut.cell_inst.neuron)*16+:16]) $fatal(1,"z frame %0d neuron %0d",i,dut.cell_inst.neuron);
   1:if(dut.cell_inst.sy!==er[int'(dut.cell_inst.neuron)*16+:16]) $fatal(1,"r frame %0d neuron %0d",i,dut.cell_inst.neuron);
   2:if(dut.cell_inst.ty!==en[int'(dut.cell_inst.neuron)*16+:16]) $fatal(1,"n frame %0d neuron %0d",i,dut.cell_inst.neuron);
   default:begin end
  endcase
 end
 task automatic wr(input logic[7:0] address,input logic[31:0] data,input bit error_expected=0);
  begin
   @(negedge clk);cfg_valid=1;cfg_write=1;cfg_addr=address;cfg_wdata=data;#1;
   if(!cfg_ready || cfg_error!==error_expected) $fatal(1,"CSR write %h data %h error=%b expected=%b",address,data,cfg_error,error_expected);
   @(negedge clk);cfg_valid=0;cfg_write=0;
  end
 endtask
 task automatic rd(input logic[7:0] address,input logic[31:0] expected);
  begin
   @(negedge clk);cfg_valid=1;cfg_write=0;cfg_addr=address;#1;
   if(!cfg_ready || cfg_error || cfg_rdata!==expected) $fatal(1,"CSR read %h got %h expected %h",address,cfg_rdata,expected);
   @(negedge clk);cfg_valid=0;
  end
 endtask
 task automatic reset_dut;
  begin
   checking=0;@(negedge clk);rst_n=0;frame_valid=0;cfg_valid=0;
   repeat(2) @(negedge clk);
   if(busy || score_valid || average_valid || degradation_alert || dut.cell_inst.hidden_state!==0 || irq) $fatal(1,"reset");
   rst_n=1;
  end
 endtask
 task automatic load_model;
  begin
   wr(0,0);wr(4,2);wr(4,4,1); // incomplete commit is rejected
   wr(8'h2c,32'h00000080,1); // invalid INT8 sign extension, index unchanged
   rd(8'h28,0);
   for(j=0;j<M+B;j=j+1) wr(8'h2c,weights[j]);
   wr(8'h2c,0,1); // past image end
   wr(8'h30,32'h12345678);wr(4,4);rd(8'h30,32'h12345678);
   wr(8'h20,63);wr(8'h1c,63);wr(0,1);
  end
 endtask
 task automatic flush_call;
  begin
   checking=0;wr(4,1);@(negedge clk);
   if(dut.cell_inst.hidden_state!==0 || running_average!=0 || score_valid || degradation_alert || !dut.model_valid || !dut.irq_status[3]) $fatal(1,"flush");
   wr(8'h20,63);
  end
 endtask
 task automatic constant_frame(input bit expected_alert);
  begin
   @(negedge clk);features='0;frame_valid=1;
   while(!frame_ready)@(negedge clk);
   @(negedge clk);frame_valid=0;
   wait(dut.cell_inst.stage==15);
   // W1C and a new DONE event on the same edge: event must win.
   @(negedge clk);cfg_valid=1;cfg_write=1;cfg_addr=8'h20;cfg_wdata=63;
   @(posedge clk);#1;
   if(!score_valid || stability_score_out!=32768 || running_average!=32768 || degradation_alert!==expected_alert || !dut.irq_status[0])$fatal(1,"constant head/hysteresis/W1C");
   @(negedge clk);cfg_valid=0;cfg_write=0;
   wr(0,0);while(busy)@(negedge clk);
  end
 endtask
 initial begin
  if(!$value$plusargs("DATA=%s",directory))directory="build/hardware";
  if(!$value$plusargs("FRAMES=%d",frames))frames=256;
  $readmemh({directory,"/image.mem"},weights);
  $readmemh({directory,"/vectors.mem"},vectors,0,frames-1);
  reset_dut();rd(8'h34,(HIDDEN<<16)|INPUTS);rd(8'h38,M+B);
  wr(0,1,1);wr(8'h0c,32'h00010002,1);wr(8'h10,9,1);wr(8'h14,1,1);wr(8'h03,0,1);wr(8'hfc,0,1);
  load_model();
  // Abort one operation by flush; then abort another by reset (model invalidates).
  @(negedge clk);frame_valid=1;@(negedge clk);frame_valid=0;
  repeat(10) @(negedge clk);flush_call();
  @(negedge clk);frame_valid=1;@(negedge clk);frame_valid=0;
  repeat(10) @(negedge clk);reset_dut();load_model();
  for(i=0;i<frames;i=i+1) begin
   if(vectors[i][0])flush_call();
   ez=vectors[i][56+64*HIDDEN+:16*HIDDEN];er=vectors[i][56+48*HIDDEN+:16*HIDDEN];
   eq=vectors[i][56+32*HIDDEN+:16*HIDDEN];en=vectors[i][56+16*HIDDEN+:16*HIDDEN];eh=vectors[i][56+:16*HIDDEN];
   @(negedge clk);features=vectors[i][VW-1-:16*INPUTS];frame_valid=1;checking=1;
   while(!frame_ready)@(negedge clk);
   @(posedge clk);begin_cycle=cycles;
   @(negedge clk);features=~features; // cannot alter latched frame
   old_score=stability_score_out;old_average=running_average;
   if(i==4)enable=0; // external disable drains work
   if(i==5)wr(8'h2c,0,1); // loading blocked during compute
   while(!score_valid) begin
    @(posedge clk);#1;
    if(busy && frame_ready)$fatal(1,"admission while busy");
    if(!score_valid && (stability_score_out!==old_score || running_average!==old_average))$fatal(1,"partial publication");
   end
   latency=cycles-begin_cycle-1;
   if(latency<min_latency)min_latency=latency;
   if(latency>max_latency)max_latency=latency;
   if(latency>=10000)$fatal(1,"latency >=1ms at 10MHz");
   if(stability_score_out!==vectors[i][55:40] || running_average!==vectors[i][39:24] || degradation_alert!==vectors[i][16] || dut.cell_inst.hidden_state!==eh || !average_valid)
    $fatal(1,"result frame %0d score=%h/%h average=%h/%h alert=%b/%b h=%h/%h",i,stability_score_out,vectors[i][55:40],running_average,vectors[i][39:24],degradation_alert,vectors[i][16],dut.cell_inst.hidden_state,eh);
   if(dut.cell_sat!==vectors[i][8] || !irq || !dut.irq_status[0])$fatal(1,"SAT/IRQ frame %0d",i);
   for(j=0;j<HIDDEN;j=j+1)if(dut.cell_inst.z[j]!==ez[j*16+:16] || dut.cell_inst.q[j]!==eq[j*16+:16] || dut.cell_inst.n[j]!==en[j*16+:16])$fatal(1,"scratch frame %0d neuron %0d",i,j);
   checking=0;
   @(negedge clk);frame_valid=0;enable=1;
   if(i%3==0)repeat(3)begin @(negedge clk);if(score_valid || average_valid)$fatal(1,"duplicate result");end
  end
  wr(0,0);while(busy)@(negedge clk);wr(8'h20,63);#1;if(irq)$fatal(1,"IRQ clear");
  // A learned, loadable head independent of mean(hidden): zero weights/bias -> 0.5.
  for(j=M-HIDDEN;j<M;j=j+1)weights[j]=0;
  weights[M+B-1]=0;load_model();wr(0,0);
  wr(8'h10,0);wr(8'h0c,{16'd50000,16'd40000});wr(0,1);constant_frame(1);
  if(!dut.irq_status[1])$fatal(1,"DEGRADE event");
  wr(8'h0c,{16'd32768,16'd10000});wr(0,1);constant_frame(1); // recovery equality holds
  wr(8'h0c,{16'd20000,16'd10000});wr(0,1);constant_frame(0);
  if(!dut.irq_status[2])$fatal(1,"RECOVER event");
  wr(8'h0c,{16'd40000,16'd32768});wr(0,1);constant_frame(0); // assertion equality holds
  // Continuously offered legal beats: second frame accepted on first ready edge.
  wr(0,1);@(negedge clk);features=0;frame_valid=1;accepted_seen=0;done_seen=0;
  while(done_seen<2)begin
   @(posedge clk);
   if(frame_valid && frame_ready)accepted_seen=accepted_seen+1;
   #1;
   if(score_valid)begin
    done_seen=done_seen+1;
    if(stability_score_out!=32768 || running_average!=32768)$fatal(1,"back-to-back result");
   end
   @(negedge clk);if(accepted_seen==2)frame_valid=0;
  end
  if(accepted_seen!=2)$fatal(1,"back-to-back acceptance count");
  while(busy)@(negedge clk);
  // Pending flush wins exactly over would-be result publication.
  wr(0,1);@(negedge clk);frame_valid=1;@(negedge clk);frame_valid=0;
  wait(dut.cell_inst.stage==14);
  @(negedge clk);cfg_valid=1;cfg_write=1;cfg_addr=4;cfg_wdata=1;
  @(negedge clk);cfg_valid=0;cfg_write=0;
  @(negedge clk);
  if(score_valid || average_valid || running_average!=0 || dut.cell_inst.hidden_state!==0 || !dut.irq_status[3])$fatal(1,"flush/completion priority");
  reset_dut();
  $display("PASS: top I=%0d H=%0d frames=%0d gates/state/score/EMA/alert exact; loader/flush/reset/backpressure; latency=%0d..%0d cycles",INPUTS,HIDDEN,frames,min_latency,max_latency);$finish;
 end
 initial begin #200000000000; $fatal(1,"top watchdog");end
endmodule

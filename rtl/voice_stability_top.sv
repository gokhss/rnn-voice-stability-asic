// Existing packed feature/result names retained; CSR protocol is docs/interface_specification.md.
module voice_stability_top #(parameter integer INPUTS=8,HIDDEN=16,
 parameter integer M=3*HIDDEN*(INPUTS+HIDDEN)+HIDDEN,B=3*HIDDEN+1)(
 input logic clk,rst_n,enable,frame_valid,
 input logic [INPUTS*16-1:0] features,
 output logic frame_ready,
 output logic [15:0] stability_score_out,running_average,
 output logic score_valid,average_valid,degradation_alert,busy,irq,
 input logic cfg_valid,cfg_write,
 input logic [7:0] cfg_addr,
 input logic [31:0] cfg_wdata,
 output logic cfg_ready,cfg_error,
 output logic [31:0] cfg_rdata
);

 localparam integer LI_W=$clog2(M+B);
 logic cfg_enabled,model_valid,loading,flush_pending;
 logic [31:0] thresholds,model_id,frame_count;
 logic [3:0] ema_shift;
 logic [5:0] irq_enable,irq_status,events,clear_events;
 logic [$clog2(M+B+1)-1:0] load_index;
 logic accept,done,cell_busy,cell_sat,initialized,core_rst_n,load_begin,load_write;
 logic [INPUTS*16-1:0] buffered;
 logic [15:0] cell_score,next_average;
 logic degradation_event,recovery_event;
 assign cfg_ready=rst_n;
 assign busy=cell_busy || score_valid || flush_pending;
 assign frame_ready=rst_n && enable && cfg_enabled && model_valid && !busy;
 assign accept=frame_valid && frame_ready;
 assign load_begin=cfg_valid && cfg_ready && cfg_write && !cfg_error && cfg_addr==8'h04 && cfg_wdata==2;
 assign load_write=cfg_valid && cfg_ready && cfg_write && !cfg_error && cfg_addr==8'h2c;
 assign core_rst_n=rst_n && !flush_pending && !load_begin;
 assign irq=|(irq_status & irq_enable);
 feature_buffer #(.INPUTS(INPUTS)) fb(.clk(clk),.rst_n(core_rst_n),.capture(accept),.features(features),.buffered(buffered));
 // Hidden state stays inside the cell; no unused top-level mirror.
 /* verilator lint_off PINCONNECTEMPTY */
 gru_cell #(.INPUTS(INPUTS),.HIDDEN(HIDDEN)) cell_inst(.clk(clk),.rst_n(core_rst_n),.start(accept),
 .features(buffered),.load_write(load_write),.load_index(load_index[LI_W-1:0]),.load_data(cfg_wdata),
 .busy(cell_busy),.done(done),.saturated(cell_sat),.score(cell_score),.hidden_state());
 /* verilator lint_on PINCONNECTEMPTY */
 moving_average #(.EMA_MODE(1)) avg_inst(.clk(clk),.rst_n(core_rst_n),.valid(done && !flush_pending),
 .score(cell_score),.window_length(5'd0),.ema_shift(ema_shift),.next_average(next_average),
 .average(running_average),.average_valid(average_valid),.initialized(initialized));
 alert_controller alert_inst(.clk(clk),.rst_n(core_rst_n),.valid(done && !flush_pending),.average(next_average),
 .threshold(thresholds[15:0]),.recovery_threshold(thresholds[31:16]),.alert(degradation_alert),
 .assert_event(degradation_event),.recover_event(recovery_event));
 always_comb begin
  cfg_error=0; cfg_rdata=0;
  if(cfg_valid) begin
   if(cfg_addr[1:0]!=0) cfg_error=1;
   else case(cfg_addr)
    8'h00:begin cfg_rdata={31'd0,cfg_enabled}; if(cfg_write && (cfg_wdata>1 || (cfg_wdata[0] && !model_valid))) cfg_error=1; end
    8'h04:begin
     if(!cfg_write) cfg_error=1;
     else case(cfg_wdata)
      0:begin end
      1:if(flush_pending || loading) cfg_error=1;
      2:if(cfg_enabled || busy) cfg_error=1;
      4:if(cfg_enabled || busy || !loading || {{(32-$clog2(M+B+1)){1'b0}},load_index}!=M+B) cfg_error=1;
      default:cfg_error=1;
     endcase
    end
    8'h08:begin cfg_rdata={26'd0,flush_pending,degradation_alert,initialized,model_valid,frame_ready,busy}; if(cfg_write) cfg_error=1; end
    8'h0c:begin cfg_rdata=thresholds; if(cfg_write && (cfg_enabled || busy || cfg_wdata[31:16]<=cfg_wdata[15:0])) cfg_error=1; end
    8'h10:begin cfg_rdata={28'd0,ema_shift}; if(cfg_write && (cfg_enabled || busy || cfg_wdata>8)) cfg_error=1; end
    8'h14:begin cfg_rdata={16'd0,stability_score_out}; if(cfg_write) cfg_error=1; end
    8'h18:begin cfg_rdata={16'd0,running_average}; if(cfg_write) cfg_error=1; end
    8'h1c:begin cfg_rdata={26'd0,irq_enable}; if(cfg_write && cfg_wdata[31:6]!=0) cfg_error=1; end
    8'h20:begin cfg_rdata={26'd0,irq_status}; if(cfg_write && cfg_wdata[31:6]!=0) cfg_error=1; end
    8'h24:begin cfg_rdata=frame_count; if(cfg_write) cfg_error=1; end
    8'h28:begin cfg_rdata={{(32-$clog2(M+B+1)){1'b0}},load_index}; if(cfg_write) cfg_error=1; end
    8'h2c:begin
     if(!cfg_write || !loading || cfg_enabled || busy || {{(32-$clog2(M+B+1)){1'b0}},load_index}>=M+B) cfg_error=1;
     if({{(32-$clog2(M+B+1)){1'b0}},load_index}<M && cfg_wdata[31:8]!={24{cfg_wdata[7]}}) cfg_error=1;
    end
    8'h30:begin cfg_rdata=model_id; if(cfg_write && (!loading || cfg_enabled || busy)) cfg_error=1; end
    8'h34:begin cfg_rdata=(HIDDEN<<16)|INPUTS; if(cfg_write) cfg_error=1; end
    8'h38:begin cfg_rdata=M+B; if(cfg_write) cfg_error=1; end
    default:cfg_error=1;
   endcase
  end
 end
 always_comb begin
  events=0; clear_events=0;
  if(flush_pending) events[3]=1;
  else if(done) begin events[0]=1; events[1]=degradation_event; events[2]=recovery_event; events[5]=cell_sat; end
  if(cfg_valid && cfg_ready && cfg_error) events[4]=1;
  if(cfg_valid && cfg_ready && cfg_write && !cfg_error && cfg_addr==8'h20) clear_events=cfg_wdata[5:0];
 end
 always_ff @(posedge clk) begin
  if(!rst_n) begin
   cfg_enabled<=0; model_valid<=0; loading<=0; flush_pending<=0; load_index<=0;
   thresholds<=32'h99998000; ema_shift<=4; irq_enable<=0; irq_status<=0;
   model_id<=0; frame_count<=0; stability_score_out<=0; score_valid<=0;
  end else begin
   irq_status<=(irq_status & ~clear_events)|events;
   score_valid<=0;
   if(flush_pending || load_begin) begin
    flush_pending<=0; frame_count<=0; stability_score_out<=0;
   end else if(done) begin stability_score_out<=cell_score; score_valid<=1; frame_count<=frame_count+1'b1; end
   if(cfg_valid && cfg_ready && cfg_write && !cfg_error) case(cfg_addr)
    8'h00:cfg_enabled<=cfg_wdata[0];
    8'h04:case(cfg_wdata)
     1:flush_pending<=1;
     2:begin loading<=1; model_valid<=0; load_index<=0; end
     4:begin loading<=0; model_valid<=1; end
     default:begin end
    endcase
    8'h0c:thresholds<=cfg_wdata;
    8'h10:ema_shift<=cfg_wdata[3:0];
    8'h1c:irq_enable<=cfg_wdata[5:0];
    8'h2c:load_index<=load_index+1'b1;
    8'h30:model_id<=cfg_wdata;
    default:begin end
   endcase
  end
 end
endmodule

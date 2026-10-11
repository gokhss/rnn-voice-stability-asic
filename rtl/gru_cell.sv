module gru_cell #(parameter integer INPUTS=8,HIDDEN=16,
 parameter integer M=3*HIDDEN*(INPUTS+HIDDEN)+HIDDEN,B=3*HIDDEN+1)(
 input logic clk,rst_n,start,
 input logic [INPUTS*16-1:0] features,
 input logic load_write,
 input logic [$clog2(M+B)-1:0] load_index,
 input logic [31:0] load_data,
 output logic busy,done,saturated,
 output logic [15:0] score,
 output logic [HIDDEN*16-1:0] hidden_state
);

 localparam integer WA_W=$clog2(M), BA_W=$clog2(B);
 /* verilator lint_off UNUSEDSIGNAL */
 logic [31:0] wa_full,ba_full;
 /* verilator lint_on UNUSEDSIGNAL */
 wire [31:0] term_u={{(32-$clog2(INPUTS+HIDDEN)){1'b0}},term};
 wire [31:0] neuron_u={{(32-$clog2(HIDDEN)){1'b0}},neuron};
 wire [31:0] phase_u={30'd0,phase};
 assign wa=wa_full[WA_W-1:0];
 assign ba=ba_full[BA_W-1:0];
 logic [3:0] stage;
 logic [1:0] phase;
 logic [$clog2(HIDDEN)-1:0] neuron;
 logic [$clog2(INPUTS+HIDDEN)-1:0] term;
 logic signed [15:0] z[0:HIDDEN-1],q[0:HIDDEN-1],n[0:HIDDEN-1];
 logic [HIDDEN*16-1:0] next_state;
 logic [$clog2(M)-1:0] wa;
 logic [$clog2(B)-1:0] ba;
 logic signed [7:0] weight;
 logic signed [31:0] bias,mac_bias;
 logic signed [15:0] a,b,result,sy,ty;
 logic clear,accumulate,mac_sat;
 logic [15:0] formatted_score;
 stability_score projection(.sigmoid_value(sy),.score(formatted_score));
 logic [3:0] shift;
 gru_controller #(.INPUTS(INPUTS),.HIDDEN(HIDDEN)) ctrl(.clk(clk),.rst_n(rst_n),.start(start),.busy(busy),.done(done),.stage(stage),.phase(phase),.neuron(neuron),.term(term));
 weight_rom #(.INPUTS(INPUTS),.HIDDEN(HIDDEN)) rom(.clk(clk),.write_enable(load_write),
  .write_index(load_index),.write_data(load_data),.weight_address(wa),.bias_address(ba),.weight(weight),.bias(bias));
 mac_unit mac(.clk(clk),.rst_n(rst_n),.clear(clear),.accumulate(accumulate),.a(a),.b(b),
  .bias(mac_bias),.shift(shift),.result(result),.saturated(mac_sat));
 sigmoid_lut sig(.x(result),.y(sy));
 tanh_lut tanh_fn(.x(result),.y(ty));
 hidden_state_reg #(.HIDDEN(HIDDEN)) hs(.clk(clk),.rst_n(rst_n),.commit(stage==11),.next_state(next_state),.state(hidden_state));
 always_comb begin
  wa_full='0; ba_full='0; a='0; b='0; mac_bias='0; shift=7;
  clear=stage==1 || stage==4 || stage==7 || stage==12;
  accumulate=stage==2 || stage==5 || stage==8 || stage==9 || stage==13;
  if(stage==1 || stage==2 || stage==3) begin
   wa_full=(phase_u*HIDDEN+neuron_u)*(INPUTS+HIDDEN)+term_u;
   ba_full=phase_u*HIDDEN+neuron_u;
   mac_bias=bias;
   if(stage==2) begin
    b={{8{weight[7]}},weight};
    if(term_u<INPUTS) a=$signed(features[term_u*16+:16]);
    else if(phase==2) a=q[term_u-INPUTS];
    else a=$signed(hidden_state[(term_u-INPUTS)*16+:16]);
   end
  end
  if(stage>=4 && stage<=10) shift=12;
  if(stage==5) begin a=q[neuron]; b=$signed(hidden_state[neuron_u*16+:16]); end
  if(stage==8) begin a=z[neuron]; b=$signed(hidden_state[neuron_u*16+:16]); end
  if(stage==9) begin a=16'sd4096-z[neuron]; b=n[neuron]; end
  if(stage>=12) begin
   wa_full=3*HIDDEN*(INPUTS+HIDDEN)+term_u; ba_full=3*HIDDEN; mac_bias=bias;
   if(stage==13) begin a=$signed(hidden_state[term_u*16+:16]); b={{8{weight[7]}},weight}; end
  end
 end
 always_ff @(posedge clk) begin
  if(!rst_n) begin next_state<='0; score<=0; saturated<=0; end
  else begin
   if(start) saturated<=0;
   if(stage==3 || stage==6 || stage==10 || stage==14) saturated<=saturated | mac_sat;
   if(stage==3) case(phase)
    0:z[neuron]<=sy;
    1:q[neuron]<=sy; // reset gate storage reused as rounded reset product
    2:n[neuron]<=ty;
    default:begin end
   endcase
   if(stage==6) q[neuron]<=result;
   if(stage==10) next_state[neuron_u*16+:16]<=result;
   if(stage==14) score<=formatted_score;
  end
 end
endmodule

module hidden_state_reg #(parameter integer HIDDEN=16)(
 input logic clk,rst_n,commit,
 input logic [HIDDEN*16-1:0] next_state,
 output logic [HIDDEN*16-1:0] state
);
 always_ff @(posedge clk) begin
   if (!rst_n) state <= '0;
   else if (commit) state <= next_state;
 end
endmodule

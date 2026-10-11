module stability_score(input logic signed [15:0] sigmoid_value,output logic [15:0] score);
 assign score=sigmoid_value>=16'sd4096 ? 16'hffff : {sigmoid_value[11:0],4'b0};
endmodule

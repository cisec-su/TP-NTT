
`include "defines.v"

module modsub(input [31:0] A,B,
              input [31:0] q,
              output[31:0] C);

wire [32:0] R;
wire [32:0] Rq;

assign R = A - B;
// assign Rq= R + {1'b0,q[31:13],13'b1};
assign Rq= R + {1'b0,q[31:13],12'h000,q[0]};

assign C = (R[32] == 0) ? R[31:0] : Rq[31:0];

endmodule

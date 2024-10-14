
`include "defines.v"

module modadd(input [31:0] A,B,
              input [31:0] q,
              output[31:0] C);

wire [32:0] R;
wire [32:0] Rq;

assign R = A + B;
//assign Rq= R - {1'b0,q[31:13],13'b1};
assign Rq= R - {1'b0,q[31:13],12'h000,q[0]};
//assign Rq = R - q;

assign C = (Rq[32] == 0) ? Rq[31:0] : R[31:0];

/*reg [32:0]        T1;
reg signed [33:0] T2, T3;
    
always@(*) begin
    T1 = A + B;
    T2 = T1 - {q[31:8],8'b1};
    T3 = T1 - {q[31:8],8'b1,1'b0};
        
    if(T3[33] == 1'b0)
        C = T3;
    else if(T2[33] == 1'b0)
        C = T2;
    else
        C = T1;
    end*/

endmodule

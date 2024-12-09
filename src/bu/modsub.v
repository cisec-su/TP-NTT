

module modsub#(
            parameter LOGQ                  =       60,
            parameter LOGQH                 =       17
        )
        (
            input [LOGQ-1:0] A,B,
            input [LOGQH-1:0] qH,
            output[LOGQ-1:0] C
        );

localparam W = LOGQ - LOGQH;

wire [LOGQ:0] R;
wire [LOGQ:0] Rq;

assign R = A - B;
assign Rq= R +  {1'b0,qH,{W-1{1'b0}},1'b1};

assign C = (R[LOGQ] == 0) ? R[LOGQ-1:0] : Rq[LOGQ-1:0];

endmodule

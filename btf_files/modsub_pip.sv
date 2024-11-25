module modsub_pip#(
            parameter LOGQ                  =       60,
            parameter Reduc_param           =       17
        )
(
  input  logic        clk,
  input  logic        rst,
  input  logic [LOGQ-1:0] A  ,
  input  logic [LOGQ-1:0] B  ,
  input  logic [LOGQ-1:0] q  ,
  output logic [LOGQ-1:0] C
);

  logic [LOGQ-1:0] q_d1;
  logic [LOGQ:0] R, R_d1;
  logic [LOGQ:0] Rq  ;

  assign C = (R_d1[LOGQ] == 0) ? R_d1[LOGQ-1:0] : Rq[LOGQ-1:0];

  always_ff @(posedge clk) begin
    if (rst) begin
      R    <= 0;
      q_d1 <= 0;
      Rq   <= 0;
      R_d1 <= 0;
    end else begin
      // Stage 1
      R    <= A - B;
      q_d1 <= q;
      // Stage 2
      Rq   <= R + {1'b0,q_d1[LOGQ-1:13],12'h000,q_d1[0]};
      R_d1 <= R;
    end
  end

endmodule


`include "defines.v"

module modmul(input        clk,rst,
              input [31:0] q,
              input [31:0] A,
              input [31:0] B,
              input [5:0]  k1_in,
              input [5:0]  k2_in,
              input [5:0]  m_in,
              output[31:0] C,
              output[31:0] C_32
             );

// q registers
reg [31:0] qred,qint;

reg [5:0]  k1;
reg [5:0]  k2;
reg [5:0]  m;

`ifdef USE_DFF_MODMUL
always @(posedge clk or posedge rst) begin
    if(rst)
        begin
            {qred,qint} <= 0;
            k1 <= 0;
            k2 <= 0;
            m <= 0;
        end
    else
        begin
            {qred,qint} <= {qint,q};
            k1 <= k1_in;
            k2 <= k2_in;
            m <= m_in;
        end
end
`else
always @(posedge clk or posedge rst) begin
    if(rst)
        begin
            qred <= 0;
            k1 <= 0;
            k2 <= 0;
            m <= 0;
        end
    else
        begin
            qred <= q;
            k1 <= k1_in;
            k2 <= k2_in;
            m <= m_in;
        end
end
`endif

// connections
wire [63:0] D;
reg  [63:0] D2;

// integer mult
intmul im(clk,rst,A,B,D);

// connection
`ifdef USE_DFF_MODMUL
always @(posedge clk or posedge rst) begin
    if(rst)
        D2 <= 0;
    else
        D2 <= D;
end
`else
always @(*) begin
    D2 = D;
end
`endif

// modular reduction

modred mr(clk,rst,qred,D2,C);


// final 32-bit
shiftreg #(.SHIFT(`MODRED_CC),.DATA(32)) sre00(clk,rst,D2[31:0],C_32);

endmodule






`include "defines.v"

// This unit can perform operations below:
// -- CT-based butterfly: 7(+1) cc latency
// -- GS-based butterfly: 7(+1) cc latency
// -- Modular add/sub   : 1 cc latency
// -- Modular mul       : 6 cc latency
// (more features will be added later ...)

module butterfly#(  parameter LOGQ = 32)

                (input clk,rst,
                 input CT,               // CT (1) or GS (0) structure
                 input MT,               // CT:0+MT:1--> a+b and (a+b)Psi
                 input [31:0] A,B,PSI,q,
                 output[31:0] E,O,       // butterfly outputs
                 output[31:0] MUL,       // modular mult output
                 output[31:0] M32,       // modular mult output (for m_tilde)
                 output[31:0] ADD,SUB);  // modular add/sub outputs

// CT:0 -> GS-based butterfly (take input from A,B,PSI -- output from E,O)
// CT:1 -> CT-based butterfly (take input from A,B,PSI -- output from E,O)
// CT:0 -> Mod Add/Sub (take input from A,B -- output from ADD/SUB)
// CT:1 -> Mod Mult (take input from B,PSI -- output from MUL)

// Signals
wire [31:0] Ar6;
wire [31:0] w0,w1;
wire [31:0] w2,w3;
reg  [31:0] w2r1,w3r1;
wire [31:0] w3r2;
wire [31:0] w2r1d6;
wire [31:0] w4;
reg  [31:0] PSIr1;
wire [31:0] PSIw;
wire [31:0] w5,w5_2,w5_3;
wire [31:0] w6;
reg  [31:0] w6r1;
wire [31:0] w7;

// Registered control signals
wire [31:0] q_addsub;
wire [31:0] q_modmul;

wire [31:0] q_d1,q_d6;
wire        mt_d1,mt_d6;

wire        ct_d,ct_o;

shiftreg #(.SHIFT(7),.DATA(1))  sre04(clk,rst,CT,ct_d);

assign ct_o = ct_d | CT;

shiftreg #(.SHIFT(1),.DATA(32)) sre00(clk,rst,q,q_d1);
shiftreg #(.SHIFT(6),.DATA(32)) sre01(clk,rst,q,q_d6);
shiftreg #(.SHIFT(1),.DATA(1))  sre02(clk,rst,MT,mt_d1);
shiftreg #(.SHIFT(6),.DATA(1))  sre03(clk,rst,MT,mt_d6);

assign q_addsub = (ct_o) ? q_d6 : q   ;
assign q_modmul = (ct_o) ? q    : q_d1;

// Operations

shiftreg #(.SHIFT(`MODMUL_CC),.DATA(32)) sre10(clk,rst,A,Ar6);

assign w0 = (ct_o) ? w5_3 : B;
assign w1 = (ct_o) ? Ar6  : A;

modadd ma0(w1,w0,q_addsub,w2);
modsub ms0(w1,w0,q_addsub,w3);

always @(posedge clk or posedge rst) begin
    if(rst)
        {w2r1,w3r1} <= 0;
    else
        {w2r1,w3r1} <= {w2,w3};
end

shiftreg #(.SHIFT(`MODMUL_CC),.DATA(32)) sre20(clk,rst,w2r1,w2r1d6);

assign w7 = (ct_o) ? w2r1 : w2r1d6;

assign w3r2 = (mt_d1) ? w2r1 : w3r1;
assign w4   = (ct_o)    ? B : w3r2;

always @(posedge clk or posedge rst) begin
    if(rst)
        PSIr1 <= 0;
    else
        PSIr1 <= PSI;
end

assign PSIw = (ct_o) ? PSI : PSIr1;

modmul#(.LOGQ(LOGQ)) mm0(clk,rst,q_modmul,w4,PSIw,w5,w5_2);

assign w6 = (ct_o) ? w3r1 : w5;

assign w5_3 = (mt_d6) ? w5_2 : w5;

always @(posedge clk or posedge rst) begin
    if(rst)
        w6r1 <= 0;
    else
        w6r1 <= w6;
end

// ---------------------------------------- Fınal Outputs

assign E = w7;
assign O = w6r1;

assign MUL = w5;
assign M32 = w5_2;

assign ADD = w2r1;
//assign ADD = w2;
assign SUB = w3r1;

endmodule

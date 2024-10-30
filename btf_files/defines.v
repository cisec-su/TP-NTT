


`timescale 1 ns / 1 ps

// Use one of them

//`define BIT_32
`define BIT_64

// Use one of them

`define USE_CSA
`define USE_DFF_MODMUL


`define INTMUL_CC 5


`ifdef BIT_32
`define MODRED_CC 4
`define LOGQ 32
`else
`define MODRED_CC 9
`define LOGQ 64
`endif

`define MODMUL_CC (`MODRED_CC + `INTMUL_CC)
`define BTRFLY_CC (`MODMUL_CC + 1)



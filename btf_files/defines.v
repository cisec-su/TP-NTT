


`timescale 1 ns / 1 ps

`define USE_CSA
`define USE_DFF_MODMUL

`ifdef USE_DFF_MODMUL
`define INTMUL_CC 2
`else
`define INTMUL_CC 1
`endif

`define MODRED_CC 4
`define MODMUL_CC (`MODRED_CC + `INTMUL_CC)
`define BTRFLY_CC (`MODMUL_CC + 1)



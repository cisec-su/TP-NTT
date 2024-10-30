


`timescale 1 ns / 1 ps

// Use one of them

`define USE_CSA
`define USE_DFF_MODMUL


`define INTMUL_CC 5

`define MODRED_CC_32 4
`define MODRED_CC_64 9

`define MODMUL_CC_32 (`MODRED_CC_32 + `INTMUL_CC)
`define MODMUL_CC_64 (`MODRED_CC_64 + `INTMUL_CC)

`define BTRFLY_CC_32 (`MODMUL_CC_32 + 1)
`define BTRFLY_CC_64 (`MODMUL_CC_64 + 1)





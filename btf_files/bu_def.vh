`ifndef BU_DEF
`define BU_DEF

`include "wlm_mixed.svh"

function [31:0] set_logqh(input int LOGQ, input int mode, input int LOGN);
    case (mode)
        1: begin 
            if (LOGQ == 60) begin
                set_logqh = 17;
            end else if  (LOGQ == 30) begin
                set_logqh = 15;
            end
        end 
        default: set_logqh = 0;
    endcase
endfunction


`define LOGN 12
`define MODE 1  // 0--> normal_wlm, 1--> wlm_mixed, 2--> mont_shift
`define LOGQ    60                              // 32 OR 64
//`define SPEED_OPT 0                             // Only valid for k2red_shift

`define LOGQH   set_logqh(`LOGQ, `MODE, `LOGN)

// Function to get latency based on mode
function [31:0] set_modred_lat(input int mode, input int LOGN);
    case (mode)
        1: begin
            set_modred_lat = wlm_mixed_lat('{`LOGQ, `LOGQH, 1, 1, 0, 1, 0, 1});
        end 
    endcase
endfunction

function [31:0] set_intmul_lat(input int mode, input int LOGN, input int STD);
    case (mode)
        1: begin 
            if (STD) begin
                set_intmul_lat = 4;
            end else begin
                set_intmul_lat = 3;
            end
        end 
        
        
        default: set_intmul_lat = 0;
    endcase
endfunction

function [31:0] set_ct_lat(input int mode, input int LOGN, input int LOGQ, input int USE_STD_in);
    set_ct_lat = set_intmul_lat(mode, LOGN, USE_STD_in) + set_modred_lat(mode, LOGN) + 1;
endfunction



`define USE_STD_MULT 0

`define USE_STD (`USE_STD_MULT ? 1 : 0)

`define USE_CSA
`define USE_DFF_MODMUL

//`define INTMUL_CC 5
`define INTMUL_CC set_intmul_lat(`MODE, `LOGN, `USE_STD)

`define MODRED_CC_32 4
//`define MODRED_CC_60 9
`define MODRED_CC_60 set_modred_lat(`MODE, `LOGN)

`define MODMUL_CC_32 (`MODRED_CC_32 + `INTMUL_CC)
`define MODMUL_CC_60 (`MODRED_CC_60 + `INTMUL_CC)

`define BTRFLY_CC_32 (`MODMUL_CC_32 + 2)
`define BTRFLY_CC_60 (`MODMUL_CC_60 + 2)

`endif
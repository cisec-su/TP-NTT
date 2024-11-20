`ifndef BTRFLY_DEFINES
`define BTRFLY_DEFINES


`include "wlm_mixed.svh"
`include "bu_def.vh"

typedef enum int {
    NONE = -1,
    WLM_MIXED = 1
} reduction_mode_t;



// Function to convert a string to the corresponding enum value
function automatic reduction_mode_t get_reduction_mode(string mode_str);
    if (mode_str == "wlm_mixed")
        return WLM_MIXED;
    else begin
        $error("Invalid mode string: %s", mode_str);
        return NONE; // Default return in case of an invalid string
    end
endfunction

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

// Variable to hold the selected mode
reduction_mode_t mode;

`define LOGN 12
`define MODE get_reduction_mode("wlm_mixed")  // 0--> normal_wlm, 1--> wlm_mixed, 2--> mont_shift
`define LOGQ    60                              // 32 OR 64
//`define SPEED_OPT 0                             // Only valid for k2red_shift


`define LOGQH   set_logqh(`LOGQ, `MODE, `LOGN)
`define W       `LOGQ - `LOGQH
`define M       `LOGQ - `LOGQH          // Only Valid for k2red_shift






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
                set_intmul_lat = 4;
            end
        end 
        
        
        default: set_intmul_lat = 0;
    endcase
endfunction

function [31:0] set_ct_lat(input int mode, input int LOGN, input int LOGQ, input int USE_STD_in);
    set_ct_lat = set_intmul_lat(mode, LOGN, USE_STD_in) + set_modred_lat(mode, LOGN) + 1;
endfunction



`define  MODRED_LAT  set_modred_lat(`MODE, `LOGN);
`define  INTMUL_LAT  set_intmul_lat(`MODE, `LOGN, `USE_STD);
`define CT_LAT  set_ct_lat(`MODE, `LOGN,`LOGQ, `USE_STD  ) + 1
`define BTRFLY_CC  `CT_LAT


`endif
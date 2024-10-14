`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/25/2024 08:54:35 PM
// Design Name: 
// Module Name: small_addr_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module iterative_tp_super_top#(
        parameter N             = 1<<16,
        parameter n1            = 1<<6,
        parameter n2            = 1<<4,
        parameter n3            = 1<<6,
        parameter TP            = 1<<6,
        parameter LOGQ          = 32,
        parameter BTF_LAT       = 8
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT_ALL,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [TP*LOGQ-1:0]           NTT_INPUT,
        input   [(TP-1)*LOGQ-1:0]       TWIDDLE_INPUT,
        output reg  [TP*LOGQ-1:0]           NTT_OUTPUT
    );



    localparam log_n1 = $rtoi($ceil($clog2(n1)));
    localparam log_n2 = $rtoi($ceil($clog2(n2)));
    localparam log_n3 = $rtoi($ceil($clog2(n3)));
    localparam depth         =  $rtoi($ceil(N/TP));
    //localparam log_TP = $rtoi($ceil($clog2(TP)));
    //localparam log_N = $rtoi($ceil($clog2(N)));
    //localparam log_size0_over_tp = $rtoi($ceil($clog2((n1*n2)/TP)));
    //localparam N_over_TP_log2 = $rtoi($ceil($clog2(N/TP)));



    // localparam OP_IDLE                  = 2'd0;
    // localparam OP_TWIDDLE_LOAD          = 2'd1;
    // localparam OP_STARTED               = 2'd2;

    //reg [1:0] OP_TYPE;

    wire START_NTT_2, START_NTT_3;

    wire [TP*LOGQ-1:0] NTT_READ_STAGE0, NTT_READ_STAGE1, NTT_READ_STAGE2;



    // always @(posedge clk or posedge rst) begin
    //     if (rst) begin
    //         OP_TYPE <= OP_IDLE;
    //     end else begin
    //         case (OP_TYPE_INPUT)
    //             2'd0: begin
    //                 if (START_NTT_ALL) begin
    //                     OP_TYPE <= OP_STARTED;
    //                 end else begin
    //                     OP_TYPE <= OP_IDLE;
    //                 end
    //             end
    //             2'd1: begin
    //                 OP_TYPE <= OP_TWIDDLE_LOAD;
    //             end 
    //             2'd2: begin
    //                 OP_TYPE <= OP_STARTED;
    //             end
    //             default: begin
    //                 OP_TYPE <= OP_IDLE;
    //             end
    //         endcase
    //     end
        
    // end


    generate
        //iterative_tp_super_unit#(1, N, n1, n2, n3, 1, TP, LOGQ, BTF_LAT) unit_super2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
        //iterative_tp_super_unit#(2, N, n1, n2, n3, 0, TP, LOGQ, BTF_LAT) unit_super3 (clk, rst, START_NTT_3 ,OP_TYPE_INPUT ,NTT_READ_STAGE1, TWIDDLE_INPUT, NTT_READ_STAGE2);
    endgenerate

    iterative_ntt_first_block#(N, n1, n2, n1*n2, TP, LOGQ, BTF_LAT, 0, 0) unit_super1 (clk, rst, START_NTT_ALL ,OP_TYPE_INPUT, NTT_INPUT, TWIDDLE_INPUT, NTT_READ_STAGE0);
    iterative_ntt_second_block#(N, n2, n1*n2, n3, TP, LOGQ, BTF_LAT) unit_super_v2 (clk, rst, START_NTT_2 ,OP_TYPE_INPUT, NTT_READ_STAGE0, TWIDDLE_INPUT, NTT_READ_STAGE1);
    iterative_ntt_first_block#(N, n3, 1, n3*1, TP, LOGQ, BTF_LAT, 1, 2) unit_super2 (clk, rst, START_NTT_3 ,OP_TYPE_INPUT, NTT_READ_STAGE1, TWIDDLE_INPUT, NTT_READ_STAGE2);



    shiftreg #(.SHIFT(BTF_LAT*log_n1+n2+4),.DATA(1)) sre101(clk,rst,START_NTT_ALL,START_NTT_2);

    shiftreg #(.SHIFT(BTF_LAT*log_n2+6+depth),.DATA(1)) sre102(clk,rst,START_NTT_2,START_NTT_3); // degisecek


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            NTT_OUTPUT <= 0;
        end else begin
            NTT_OUTPUT <= NTT_READ_STAGE2;
        end    
    end
    



endmodule

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


module small_addr_gen_upd#(
        parameter N             = 128,
        parameter n1            = 8,
        parameter n2            = 2,
        parameter size0         = 16,
        parameter TP            = 8,
        parameter LOGQ          = 32,
        parameter BTF_LAT       = 8
    )
(
        input                                     clk      ,
        input                                     rst      ,
        input                                     start    ,
        output reg [(log_size0_over_tp+1)*TP-1:0] read_addr,
        output reg [(log_size0_over_tp+1)*TP-1:0] write_addr     
    );

localparam log_n2 = $rtoi($ceil($clog2(n2)));
localparam size0_over_tp = $rtoi($ceil((size0)/TP));
localparam log_size0_over_tp = $rtoi($ceil($clog2(size0_over_tp)));

// states
localparam OP_IDLE          = 1'd0;
localparam OP_STARTED       = 1'd1;


wire [log_size0_over_tp:0] read_addr_int [0:TP-1];
reg  [log_size0_over_tp:0] ctr;
reg  OP_TYPE;
reg  curr_state, next_state;


always @(posedge clk) 
begin
    if(rst)
        curr_state <= OP_IDLE;
    else
        curr_state <= next_state;
end

always @(*) begin
    next_state = curr_state;
    if (start) begin
        next_state = OP_STARTED;
    end else begin
        next_state = OP_IDLE;
    end
end


always @(posedge clk or posedge rst) begin
    if (rst) begin
        ctr <= 0;
    end else begin
        case (curr_state)
            OP_STARTED: begin
                ctr <= ctr + 1;
            end 
            default: begin
                ctr <= ctr;
            end
        endcase
        
    end
end


generate
    for (genvar i = 0; i < TP; i = i + 1) begin
        assign read_addr_int[i] = (i&(size0_over_tp-1)) + size0_over_tp*(ctr<size0_over_tp);
    end
endgenerate


generate
    for (genvar i = 0; i < TP; i = i + 1) begin
        always @(posedge clk) begin
            read_addr [((TP-i)*(log_size0_over_tp+1))-1 -: log_size0_over_tp+1] <= (OP_STARTED) ? read_addr_int[((i + TP) - (ctr&((size0_over_tp)-1))) & (TP-1)] : 0;
        end
        always @(posedge clk) begin
            write_addr[((TP-i)*(log_size0_over_tp+1))-1 -: log_size0_over_tp+1] <= (OP_STARTED) ? ctr : 0;
        end
    end
endgenerate


endmodule
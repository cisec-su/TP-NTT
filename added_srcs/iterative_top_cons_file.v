// top_module.v

module iterative_tp_cons_file #(
        parameter N             = 1<<12,
        parameter n1            = 1<<6,
        parameter n2            = 1<<6,
        parameter n3            = 1<<0,
        parameter n4            = 1<<0,     
        parameter TP            = 1<<7,
        parameter LOGQ          = 32
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT_ALL,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [LOGQ-1:0]              Q_in,
        input   [LOGQ-1:0]              NTT_INPUT,
        input   [LOGQ-1:0]              TWIDDLE_INPUT,
        output reg  [LOGQ-1:0]          dout
    );


    // Parameters for the karatsuba_parametric module
    
    localparam log_TP = $rtoi($ceil($clog2(TP)));

    reg [LOGQ-1:0]      din_R      [LOGQ-1:0];

    wire[LOGQ-1:0]      dout_W     [LOGQ-1:0];

    reg [LOGQ-1:0] Q_in_reg;

    reg [log_TP-1:0]       i_cntr;

    reg [log_TP-1:0]       o_cntr;

    reg START_NTT_reg;

    reg [1:0] OP_TYPE_reg;

    wire [TP*LOGQ-1:0] dout_total;

    always @(posedge clk or posedge rst) 
    begin
        if(rst) begin
            i_cntr <= 0;
            
            o_cntr <= 0;
            
        end
        else begin
            i_cntr <= i_cntr+1;
            
            o_cntr <= o_cntr+1;
        end
    end
    
    always @(posedge clk or posedge rst) 
    begin
        if(rst) begin
            
    
            {din_R[31],din_R[30],din_R[29],din_R[28],din_R[27],din_R[26],din_R[25],din_R[24],din_R[23],din_R[22],din_R[21],din_R[20],din_R[19],din_R[18],din_R[17],din_R[16],din_R[15],din_R[14],din_R[13],din_R[12],din_R[11],din_R[10],din_R[9],din_R[8],din_R[7],din_R[6],din_R[5],din_R[4],din_R[3],din_R[2],din_R[1],din_R[0]} <= 0;

            dout          <= 0;
            START_NTT_reg <= 0;
            OP_TYPE_reg <= 0;
            Q_in_reg <= 0;
        end
        else begin
            
            //done          <= done_wire;
    
            din_R[i_cntr] <= NTT_INPUT;
            dout          <= dout_total[LOGQ*(o_cntr+1)-1-:LOGQ];
            START_NTT_reg <= START_NTT_ALL;
            OP_TYPE_reg <= OP_TYPE_INPUT;
            Q_in_reg <= Q_in;
        end
    end

    iterative_tp_super_top #(
        .N(N),
        .n1(n1),
        .n2(n2),
        .n3(n3),
        .n4(n4),
        .TP(TP),
        .LOGQ(LOGQ)
    ) unit(clk,rst, START_NTT_reg, OP_TYPE_reg, Q_in_reg,
            {TP*{din_R[i_cntr]}},
            {(TP-1)*{din_R[i_cntr]}},
            dout_total
             );
    

endmodule
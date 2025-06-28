// top_module.v

module iterative_tp_cons_file #(
        parameter LOGN          = 16,
        parameter LOGN1         = 6,
        parameter LOGN2         = 4,
        parameter LOGN3         = 6,
        parameter LOGTP         = 6,
        parameter LOGQ          = 60,
        parameter LOGQH         = 17
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
    localparam N  = 1 << LOGN;
    localparam TP = 1 << LOGTP;

    reg [LOGQ-1:0]      din_R      [LOGQ-1:0];

    wire[LOGQ-1:0]      dout_W     [LOGQ-1:0];

    reg [LOGQ-1:0] Q_in_reg;

    reg [LOGTP-1:0]       i_cntr;

    reg [LOGTP-1:0]       o_cntr;

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

    tp_ntt_top #(
        .LOGN(LOGN),
        .LOGN1(LOGN1),
        .LOGN2(LOGN2),
        .LOGN3(LOGN3),
        .LOGTP(LOGTP),
        .LOGQ(LOGQ),
        .LOGQH(LOGQH)
    ) unit(clk,rst, START_NTT_reg, OP_TYPE_reg, Q_in_reg[LOGQ-1 -:LOGQH],
            {TP*{din_R[i_cntr]}},
            {(TP-1)*{din_R[i_cntr]}},
            dout_total
             );
    

endmodule
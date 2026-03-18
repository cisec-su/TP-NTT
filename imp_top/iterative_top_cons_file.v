// top_module.v

module iterative_tp_cons_file #(
        parameter LOGN          = 16,
        parameter LOGN1         = 6,
        parameter LOGN2         = 4,
        parameter LOGN3         = 6,
        parameter LOGTP         = 6,
        parameter LOGQ          = 60,
        parameter LOGQH         = 17,
        parameter TW_STREAM     = 0
    )
    (
        input                           clk,
        input                           rst,
        input                           START_NTT_ALL,
        input   [1:0]                   OP_TYPE_INPUT,
        input   [LOGQ-1:0]              Q_in,
        input                           intt_in,    
        input                           shuffle_mod_in,
        input   [LOGQ-1:0]              NTT_INPUT,
        input   [LOGQ-1:0]              TWIDDLE_INPUT,
        output reg  [LOGQ-1:0]          dout
    );


    // Parameters for the karatsuba_parametric module
    localparam N  = 1 << LOGN;
    localparam TP = 1 << LOGTP;

    reg [LOGQ-1:0]      din_R      [TP-1:0];
    reg [LOGQ-1:0]      din_T      [TP-1:0];

    wire[LOGQ-1:0]      dout_W     [TP-1:0];

    reg [LOGQ-1:0] Q_in_reg;

    reg [LOGTP-1:0]       i_cntr;

    reg [LOGTP-1:0]       o_cntr;

    reg START_NTT_reg;

    reg [1:0] OP_TYPE_reg;

    wire [TP*LOGQ-1:0] dout_total;

    reg shuffle_mod_reg, intt_reg;

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
    
    always @(posedge clk) 
    begin
    
            din_R[i_cntr] <= NTT_INPUT;
            din_T[i_cntr] <= TWIDDLE_INPUT;
            dout          <= dout_total[LOGQ*(o_cntr+1)-1-:LOGQ];
            START_NTT_reg <= START_NTT_ALL;
            OP_TYPE_reg <= OP_TYPE_INPUT;
            Q_in_reg <= Q_in;
            intt_reg <= intt_in;
            shuffle_mod_reg <= shuffle_mod_in;
    end


tp_ntt_top #(
    .LOGN  (LOGN),
    .LOGN1 (LOGN1),
    .LOGN2 (LOGN2),
    .LOGN3 (LOGN3),
    .LOGTP (LOGTP),
    .LOGQ  (LOGQ),
    .LOGQH (LOGQH),
    .TW_STREAM (TW_STREAM)
) unit (
    .clk          (clk),
    .rst          (rst),
    .start        (START_NTT_reg),
    .op           (OP_TYPE_reg),
    .intt         (intt_reg),           // you must provide this
    .shuffle_mod  (shuffle_mod_reg),    // you must provide this
    .qH           (Q_in_reg[LOGQH-1:0]),
    .i_poly       ({TP*{din_R[i_cntr]}}),
    .psi          ({TP*{din_T[i_cntr]}}),            // you must provide this
    .o_poly       (dout_total)
);
    

endmodule
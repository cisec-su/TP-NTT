

`timescale 1ns / 1ps

//`include "wlm.svh"

`include "bu_def.vh"

module btf_tb();

    // Parameters
    localparam CLK_PERIOD = 10; // Clock period in ns

    // parameter LOGQ      = 64;
    // parameter R         = 17;
    // parameter LOGQH     = LOGQ-R;

    // parameter intmul_cc = 4;
    // parameter modred_cc = 11;
    // parameter modmul_cc = intmul_cc + modred_cc;

    // parameter wlm_params_t params = {R, LOGQ, LOGQH, 1, 0, 0, 1, 0, 1};
    // parameter LAT =  wlm_lat(params);

    // parameter intmul_cc = 4;
    // parameter modmul_cc = intmul_cc + LAT + 1;

    parameter CT_latency = `BTRFLY_CC_60 ;
    //parameter modred_cc_cycle = modred_cc*10;

    parameter modmul_cc_cycle = CT_latency*10;



    // Signals
    reg clk;
    reg rst;
    reg CT;
    reg MT;
    reg [`LOGQ-1:0] A, B, q;
    reg [`LOGQ-1:0] PSI;
    reg [5:0] k1_in, k2_in, m_in; 
    wire [`LOGQ-1:0] E, O, MUL, M64, ADD, SUB;

    reg [4:0] L1, L2, L3;


    // Instantiate the module under test
    butterfly #(
        .LOGQ(`LOGQ),
        .LOGQH(`LOGQH),
        .USE_STD(`USE_STD)
    ) 
    dut (
        .clk(clk),
        .rst(rst),
        .CT(CT),
        .MT(MT),
        .A(A),
        .B(B),
        .PSI(PSI),
        .q(q),
        .E(E),
        .O(O),
        .MUL(MUL),
        .M32(M64),
        .ADD(ADD),
        .SUB(SUB)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Initial stimulus
    initial begin
        // Initialize inputs
        clk = 0;
        rst = 1;
        A = 32'd0;
        B = 32'd0;
        PSI = 32'd0;
        CT = 1'b0;
        MT = 0;
        L1 = 0;
        L2 = 0;
        L3 = 0;
        k1_in = 6'd0;
        k2_in = 6'd0;
        m_in = 6'd0;
        q = 32'd0;
        #10;
        rst = 0;
        #5;
        rst = 0;
        #10;
        q = 60'd576557509326667777;
        L1 = 15;
        L2 = 10;
        L3 = 0;
        #50;

        // Cooley-Tukey
        CT = 1;
        MT = 0;
        A = 60'ha5d2f36baa9455;
        B = 60'h247b34fcc2c158b;
        PSI = 60'h8ddbb3edb50990;
        k1_in = 6'd0;
        k2_in = 6'd0;
        m_in = 6'd0;

        #10;
        A = 60'h7c65c1e82e2e662;
        B = 60'h42a119e7facf1e1;
        PSI = 60'h8ddbb3edb50990;


        
        #(modmul_cc_cycle - 10);
        
        if(E == 60'h6fd274ec8cac507)
            $display("word_level_mont_parametric Cooley-Tukey Even check True: ");
        else
            $display("word_level_mont_parametric Cooley-Tukey Even check False: ");
       
        //#10;
        if(O == 60'h24ed6980e8a63a4)
            $display("word_level_mont_parametric Cooley-Tukey Odd check True: ");
        else
            $display("word_level_mont_parametric Cooley-Tukey Odd check False: ");
        
        #10;
        if(E == 60'h3cf1ebe7cf2b50c)
            $display("word_level_mont_parametric Cooley-Tukey Even check True: ");
        else
            $display("word_level_mont_parametric Cooley-Tukey Even check False: ");
       
        //#10;
        if(O == 60'h3bd417e88d317b7)
            $display("word_level_mont_parametric Cooley-Tukey Odd check True: ");
        else
            $display("word_level_mont_parametric Cooley-Tukey Odd check False: ");
       
        #400;
        
        
        // Add more stimulus if needed

        // Add delay before ending simulation
        #1000;
        $finish;

        
    end

endmodule



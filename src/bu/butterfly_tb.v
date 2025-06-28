`timescale 1ns/1ps

module butterfyl_tb;

    `include "butterfly.svh"

    // Parameters
    localparam LOGQ     = 60;
    localparam LOGQH    = 17;

    // DUT Inputs
    reg                   clk;
    reg                   CT;
    reg  [LOGQ -1:0]      A;
    reg  [LOGQ -1:0]      B;
    reg  [LOGQ -1:0]      psi;
    reg  [LOGQH-1:0]      qH;
    reg  [LOGQ-1:0] q_in [0:0];

    // DUT Outputs
    wire [LOGQ -1:0]      E;
    wire [LOGQ -1:0]      O;

    // Instantiate the DUT
    butterfly #(
        .LOGQ(LOGQ),
        .LOGQH(LOGQH),
        .NON_STD(1),
        .MORE_DSP(0)
    ) dut (
        .clk(clk),
        .CT(CT),
        .A(A),
        .B(B),
        .psi(psi),
        .qH(qH),
        .E(E),
        .O(O)
    );
    
    parameter TEST_DIR      = "../../../../../test";
    
    parameter butterfly_params_t butterfly_params = {32'd60, 32'd17, 32'd1, 32'd0};
    parameter modadd_params_t modadd_params = butterfly_modadd_params(butterfly_params);
    parameter modmul_wlm_params_t modmul_wlm_params = butterfly_modmul_wlm_params(butterfly_params);
    parameter MODMUL_LAT = modmul_wlm_lat(modmul_wlm_params);
    parameter LAT = butterfly_lat(butterfly_params);

    // Clock generation
    initial clk = 1;
    always #5 clk = ~clk;  // 100MHz clock
    
    initial begin
   end

    // Stimulus
    initial begin
        q_in[0] = 60'h800580000000001;

        $display("Starting testbench...");
        // Initialize inputs
        CT   = 0;
        A    = 0;
        B    = 0;
        psi  = 0;
        qH   = q_in[0][LOGQ-1 -: LOGQH];

        // Wait for a few cycles
        #20;

        // Apply test vectors
        CT   = 0;
        A    = 60'h3fd423ffc33530c;
        B    = 60'h6d31f7821276e88;
        psi  = 60'hd0f5e648afa14e;
        qH   = q_in[0][LOGQ-1 -: LOGQH];
        
        #10;  
        A = 0;
        B = 0;
        psi = 0;
        A    = 60'h373b2880152a83a;
        B    = 60'h1acb4cff48f235;
        psi  = 60'h58cf5c0df907821;
        qH   = q_in[0][LOGQ-1 -: LOGQH];
        #10
        
        A    = 60'h60b1118b6b1aaa5;
        B    = 60'h5231947a7f306fd;
        psi  = 60'h15b6a8b7707971a;
        qH   = q_in[0][LOGQ-1 -: LOGQH];
        #10
         
        #((LAT-3) * 10);

        $display("Result E : %d", E == 60'h56830dc0ead60ca);
        $display("Result O : %d", O == 60'h7cbeeb49b2e7836);
        
 
        #(10);

        $display("Result E : %d", E == 60'h5c76aea804dcd38);
        $display("Result O : %d", O == 60'h42992eb03c60abf);
        
        #(10);

        $display("Result E : %d", E == 60'h59715302f5258d1);
        $display("Result O : %d", O == 60'h4e4ab981f8bb2d5);

        // Add more vectors if needed
        $finish;
    end

endmodule





module intmul(input clk,rst,
              input [31:0] A,B,
              output reg [63:0] D);

(* use_dsp = "yes" *) reg [31:0] p00,p01,p10,p11;

always @(posedge clk or posedge rst) begin
    if(rst) begin
        p00 <= 0;
        p01 <= 0;
        p10 <= 0;
        p11 <= 0;
    end
    else begin
        p00 <= A[15:0] * B[15:0];
        p01 <= A[15:0] * B[31:16];
        p10 <= A[31:16] * B[15:0];
        p11 <= A[31:16] * B[31:16];
    end
end

wire [47:0] p;

`ifdef USE_CSA

wire [31:0] i0,i1,i2;
wire [31:0] c,s;

assign i0 = {{p11[15:0],p00[31:16]}};
assign i1 = p01;
assign i2 = p10;

generate
	genvar fa_idx;

	for(fa_idx=0; fa_idx<32; fa_idx=fa_idx+1) begin: FA_LOOP
		FA fau(i0[fa_idx],i1[fa_idx],i2[fa_idx],c[fa_idx],s[fa_idx]);
	end
endgenerate

assign p = {{p11[31:16],s}} + {{c,1'b0}};

`else

assign p = {{p11,p00[31:16]}} + p01 + p10;

`endif

always @(*) begin
    D = {{p,p00[15:0]}};
end

endmodule



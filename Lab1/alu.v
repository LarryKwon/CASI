`timescale 1ns / 100ps

module ALU(A,B,OP,C,Cout);

	input [15:0]A;
	input [15:0]B;
	input [3:0]OP;
	output [15:0]C;
	output Cout;

	//TODO
	reg [15:0] ALU_RESULT;

	assign C = ALU_RESULT;


	wire[16:0] tmp_for_c1;
	wire[15:0] tmp_for_c2;

	assign tmp_for_c1 = {1'b0,A}+{1'b0+B};
	assign tmp_for_c2 = {1'b0,A[14:0]} + {1'b0+B[14:0]};
	
	assign Cout = tmp_for_c1[16]^tmp_for_c2[15];

	always @(*)
	begin
		case(OP)
			4'b0000: ALU_RESULT = A+B;
			4'b0001: ALU_RESULT = A-B;
			4'b0010: ALU_RESULT = A&B;
			4'b0011: ALU_RESULT = A|B;
			4'b0100: ALU_RESULT = ~(A&B);
			4'b0101: ALU_RESULT = ~(A|B);
			4'b0110: ALU_RESULT = A^B;
			4'b0111: ALU_RESULT = ~(A^B);
			4'b1000: ALU_RESULT = A;
			4'b1001: ALU_RESULT = ~A;
			4'b1010: ALU_RESULT = A>>1;
			4'b1011: ALU_RESULT = $signed(A)>>>1;
			4'b1100: ALU_RESULT = {A[0],A[15:1]};
			4'b1101: ALU_RESULT = A << 1;
			4'b1110: ALU_RESULT = $signed(A) <<< 1;
			4'b1111: ALU_RESULT = {A[14:0],A[15]};
			default: ALU_RESULT = A+B;
		endcase
	end
endmodule

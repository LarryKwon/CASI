module RISCV_TOP (
	//General Signals
	input wire CLK,
	input wire RSTn,

	//I-Memory Signals
	output wire I_MEM_CSN, // RSTn == 1 -> CSN = 0, RSTn == 0 -> CSN = 1
	input wire [31:0] I_MEM_DI,//input from IM
	output reg [11:0] I_MEM_ADDR,//in byte address

	//D-Memory Signals
	output wire D_MEM_CSN, // RSTn == 1 -> CSN = 0, RSTn == 0 -> CSN = 1
	input wire [31:0] D_MEM_DI, // read data 
	output wire [31:0] D_MEM_DOUT, // write data
	output wire [11:0] D_MEM_ADDR,//in word address
	output wire D_MEM_WEN, // write시 WEN = 0
	output wire [3:0] D_MEM_BE, // byte enable 값

	//RegFile Signals
	output wire RF_WE, // register에 값을 쓸 때 1, 아니면 0
	output wire [4:0] RF_RA1, // register1의 넘버
	output wire [4:0] RF_RA2, // register2의 넘버
	output wire [4:0] RF_WA1, // write regiserdml 넘버
	input wire [31:0] RF_RD1, //  RA1로부터의 값
	input wire [31:0] RF_RD2, // RA2로부터의 값
	output wire [31:0] RF_WD, // register에 쓸 값
	output wire HALT, // terminate
	output reg [31:0] NUM_INST, // 몇 번째 inst인지, 끝날 때 1씩 올려야한다.
	output wire [31:0] OUTPUT_PORT // 
	);

	// TODO: implement multi-cycle CPU

	//connect to I_MEM
	// IR_WRITE 필요 -> control_unit
	reg[31:0] I_MEM_DI_reg;
	assign I_MEM_DI = I_MEM_DI_reg;
	assign I_MEM_CSN = ~RSTn;

	//connect to regfile
	//reg1_control, reg2_control -> control_unit
	assign RF_RA1 = I_MEM_DI_reg[19:15];
	assign RF_RA2 = I_MEM_DI_reg[24:20];
	assign RF_WA1 = I_MEM_DI_reg[11:7];
	
	reg[31:0] RF_RD1_reg; //RD1값 저장 reg
	reg[31:0] RF_RD2_reg; //RD2값 저장 reg
	assign RF_RD1 = RF_RD1_reg;
	assign RF_RD2 = RF_RD2_reg;

	//ImmGen
	wire[31:0] imm;

	//termination & output Port
	wire termination_flag = 0;
	reg termination_flag_reg;
	reg[6:0] opcode;
	reg HALT_reg;

	assign termination_flag = termination_flag_reg;
	assign HALT = HALT_reg;
	assign opcode = I_MEM_DI[6:0];

	//alu unit
	wire[31:0] alu_result;
	reg[31:0] alu_Out;
	assign alu_result = alu_Out;

	//BranchComp
	wire[1:0] br_control; // BranchComp in alu_unit to controlUnit

	//connect to D_MEM
	assign D_MEM_CSN = ~RSTn;
	assign D_MEM_DOUT = RF_RD2_reg; //Write Data 연결
	assign D_MEM_ADDR = alu_Out & 16'h3FFF; //Mem Addr 연결


	//pc
	//pcWrite 필요 -> control_unit
	reg [11:0] pc;
	reg [11:0] old_pc;

	always @(*) begin // old_pc에 pc값을 연결
		if(ir_write_control == 1) begin
			old_pc = pc;
		end
	end
	
	//port instantiation of ImmGen
	ImmGen imm_gen1(
		.RSTn			(RSTn),
		.imm_control	(imm_control),
		.I_MEM_DI		(I_MEM_DI),
		.imm			(imm)
	);

	AluUnit alu_unit(
		 .RSTn			(RSTn),
		 .ASel			(ASel),
		 .BSel			(BSel),
		 .is_sign		(is_sign),
		 .alu_control	(alu_control),
		 .RF_RD1		(RF_RD1), // source register 1로 부터 읽을 값
		 .RF_RD2		(RF_RD2), // source register 2로 부터 읽을 값
		 .imm			(imm),
		 .pc			(pc),
		 .old_pc		(old_pc),
		 .alu_result	(alu_result),
		 .br_control	(br_control)
	);

	ControlUnit control_unit(
		.RSTn			(RSTn),
		.I_MEM_DI		(I_MEM_DI),
		.br_control		(br_control),	
		.imm_control	(imm_control),
		.RF_WE			(RF_WE),
		.D_MEM_WEN		(D_MEM_WEN),
		.D_MEM_BE		(D_MEM_BE),
		.is_sign		(is_sign),
		.ASel			(ASel),
		.BSel			(BSel),
		.alu_control	(alu_control),
		.wb_control		(wb_control),
		.pcSel			(pcSel)
	);

	initial begin
		NUM_INST <= 0;
		pc <= 0;
	end

	always @(RSTn) begin
		
		I_MEM_ADDR = pc;
		
	end


	//I_MEM_ADDR 설정
	// 종료 조건 설정
	always@(*) begin
		I_MEM_ADDR = pc & 12'hFFF;

		if(I_MEM_DI == 32'h00c00093 ) begin
			termination_flag_reg = 1;
		end
		else begin
			if(I_MEM_DI == 32'h00008067 && termination_flag_reg == 1) begin
				termination_flag_reg = 1;
			end
			else begin
				termination_flag_reg = 0;
			end
		end

		if(termination_flag_reg & (I_MEM_DI == 32'h00008067)) begin
			HALT_reg = 1;
		end 
		else begin
			HALT_reg = 0;
		end
	end

	always @(posedge CLK) begin
		//Num_Inst 계산 어떻게 할지
		// pc <= next_pc 값이 언제, 어떻게 일어나는지
		//
	end
	
endmodule //

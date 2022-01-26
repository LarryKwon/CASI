module RISCV_TOP (
	//General Signals
	input wire CLK,
	input wire RSTn,

	//I-Memory Signals
	output wire I_MEM_CSN,
	input wire [31:0] I_MEM_DI,//input from IM
	output reg [11:0] I_MEM_ADDR,//in byte address

	//D-Memory Signals
	output wire D_MEM_CSN,
	input wire [31:0] D_MEM_DI,
	output wire [31:0] D_MEM_DOUT,
	output wire [11:0] D_MEM_ADDR,//in word address
	output wire D_MEM_WEN,
	output wire [3:0] D_MEM_BE,

	//RegFile Signals
	output wire RF_WE,
	output wire [4:0] RF_RA1,
	output wire [4:0] RF_RA2,
	output wire [4:0] RF_WA1,
	input wire [31:0] RF_RD1,
	input wire [31:0] RF_RD2,
	output wire [31:0] RF_WD,
	output wire HALT,                   // if set, terminate program
	output reg [31:0] NUM_INST,         // number of instruction completed
	output wire [31:0] OUTPUT_PORT      // equal RF_WD this port is used for test
	);

    /* wire 및 reg 선언부 */
    //register 및 wire
    
    //IF
    reg [11:0] pc; 
    reg [31:0] INST_IF_ID;   
    reg [11:0] pc_IF_ID;

    //ID
    reg [31:0] RF_RD1_ID_EX; //RD1값 저장 reg
	reg [31:0] RF_RD2_ID_EX; //RD2값 저장 reg
    reg [11:0] pc_ID_EX;
    reg [31:0] INST_ID_EX;
    wire[4:0]  RA1_EX;
    wire[4:0] RA2_EX;

    //ex
    wire[31:0] imm;
    reg [31:0] alu_out;
    reg [31:0] RF_RD2_EX_MEM;
    reg [11:0] pc_EX_MEM;
    reg [31:0] INST_EX_MEM;
    wire[4:0] WA_MEM;
    //alu unit
	wire[31:0] alu_result;
    reg [31:0] alu_out;
    //BranchComp
	wire BrEq; // BranchComp to controlUnit
	wire BrLt; // BranchComp to controlUnit

    //MEM

    //WB
    reg [31:0] RF_WD_MEM_WB;
    reg [31:0] INST_MEM_WB;
    wire[4:0] WA_WB;

    // control signals
    /* control unit에서 나오는 wire*/
    //EX
    wire [4:0] alu_control;
    wire is_sign;
    wire [2:0] imm_control;
    wire ASel;
    wire BSel;
    //MEM
    wire memWrite;
    wire [3:0] memByte;
    //WB
    wire [1:0] wbSel;
    wire regWrite;

    /* ID/EX 단계 */
    //EX
    reg [4:0] alu_control_ID_EX;
    reg is_sign_ID_EX;
    reg [2:0] imm_control_ID_EX;
    reg ASel_ID_EX;
    reg BSel_ID_EX;
    //MEM
    reg memWrite_ID_EX;
    reg [3:0] memByte_ID_EX;
    //WB
    reg [1:0] wbSel_ID_EX;
    reg regWrite_ID_EX;

    /* EX/MEM 단계 */
    //MEM
    reg memWrite_EX_MEM;
    reg [3:0] memByte_EX_MEM;
    //WB
    reg [1:0] wbSel_EX_MEM;
    reg regWrite_EX_MEM;

    /* MEM/WB 단계 */
    //WB
    reg regWrite_MEM_WB;

    /*for stall*/    
    wire isNop_IF_ID;
    wire isNop_ID_EX;
    wire IF_ID_WE;
    wire pcWrite;

    //forwardUnit
    wire [1:0] forwardA;
    wire [1:0] forwardB;
    
    /*BTB <-> control unit*/
    wire misPredict; // BTB to controlUnit
    wire pred; // BTB to PC
    wire isTaken; // controlUnit to BTB
    wire target_addr; // BTB to PC

	//output port -> 수정 필요
	assign OUTPUT_PORT = (opcode == 7'b1100011)? ~misPredict:
	(opcode == 7'b0100011)? alu_out : RF_WD;

    /*초기화 */
	initial begin
		NUM_INST <= 0;
        pc <= 0;

	end
    
    assign I_MEM_CSN = ~RSTn;
    assign D_MEM_CSN = ~RSTn;
    always @(RSTn) begin
		I_MEM_ADDR = pc;
		INST_IF_ID = I_MEM_DI;
	end

	// Only allow for NUM_INST
	always @ (negedge CLK) begin
		if (RSTn) NUM_INST <= NUM_INST + 1;
	end

    /*포트 연결부*/
    BranchComp branch_comp(
		.RSTn 		(RSTn),
		.is_sign 	(is_sign_ID_EX),
		.RF_RD1  	(RF_RD1_ID_EX), // source register 1로 부터 읽을 값
		.RF_RD2  	(RF_RD2_ID_EX), // source register 2로 부터 읽을 값
   		.BrEq    	(BrEq),
    	.BrLt    	(BrLt)
	);

    ImmGen imm_gen1(
		.RSTn				(RSTn),
		.imm_control	    (imm_control_ID_EX),
		.I_MEM_DI			(INST_ID_EX),
		.imm				(imm)
	);

    AluUnit alu_unit(
        .RSTn			(RSTn),
        .ASel           (ASel_ID_EX),
        .BSel           (BSel_ID_EX),
        .forwardA		(forwardA),
        .forwardB		(forwardB),
        .is_sign		(is_sign_ID_EX),
        .alu_control	(alu_control_ID_EX),
        .RF_RD1			(RF_RD1_ID_EX), // source register 1로 부터 읽을 값
        .RF_RD2			(RF_RD2_ID_EX), // source register 2로 부터 읽을 값
        .imm			(imm),
        .pc				(pc_ID_EX),
        .SRC1_EX_MEM    (alu_out),
        .SRC2_EX_MEM    (alu_out),
        .SRC1_MEM_WB    (RF_WD_MEM_WB),
        .SRC2_MEM_WB    (RF_WD_MEM_WB),
        .alu_result	    (alu_result)
	);

	ControlUnit control_unit(
		.RSTn			(RSTn),
		.INST_IF_ID		(INST_IF_ID),
        .INST_ID_EX     (INST_ID_EX),
		.BrEq			(BrEq),		
		.BrLt			(BrLt),
		.imm_control	(imm_control),
		.regWrite		(regWrite),
		.memWrite		(memWrite),
		.memByte		(memByte),
		.is_sign		(is_sign),
		.ASel			(ASel),
		.BSel			(BSel),
		.alu_control	(alu_control),
		.wbSel		    (wbSel),
        .misPredict     (misPredict),
        .isTaken        (isTaken),
        .pcWrite        (pcWrite),
        .IF_ID_WE       (IF_ID_WE),
        .isNop_IF_ID    (isNop_IF_ID),
        .isNop_ID_EX    (isNop_ID_EX)
	);

    ForwardUnit forward_unit(
        .RSTn           (RSTn),
		.RS1_EX			(INST_ID_EX[19:15]),
        .RS2_EX         (INST_ID_EX[24:20]),
        .RD_MEM         (INST_EX_MEM[11:7]),
        .RD_WB          (INST_MEM_WB[11:7]),
        .regWrite_MEM   (regWrite_EX_MEM),
        .regWrite_WB    (regWrite_MEM_WB)
	);

    BTB btb(
        .RSTn           (RSTn),
        .INST_ID_EX     (INST_ID_EX),
        .pc_ID_EX       (pc_ID_EX),
        .pc             (pc),
        .isTaken        (isTaken),
        .alu_result     (alu_result),
        .target_addr    (target_addr),
        .pred           (pred),
        .misPredict     (misPredict)
    )

    /* datapath 연결부 */

    /*IF datapath*/
    always @(*) begin
        I_MEM_ADDR = pc & 12'hFFF;
    end
    /*
        @Todo: pc +4  and BTB logic 추가
    */

    // IF/ID register
    //instruction reg
    always @(posedge CLK) begin
        // @Todo: isNop_IF_ID, IF_ID_WE에 따른 stall 과 noop 기능 추가
        INST_IF_ID <= I_MEM_DI;
    end
    //pc
    always @(posedge CLK) begin
        pc_IF_ID <= pc;
    end


    /*ID datapath*/
    //connect to RA1, RA2 of RegisterFile
	assign RF_RA1 = INST_IF_ID[19:15];
	assign RF_RA2 = INST_IF_ID[24:20];
	
    // ID/EX register
    // RF_RD1, RF_RD2
	always @(posedge CLK) begin
		RF_RD1_ID_EX <= RF_RD1;
		RF_RD2_ID_EX <= RF_RD2;
	end
    //pc_IFID
    always @(posedge CLK) begin
        pc_ID_EX <= pc_IF_ID;
    end
    //instruction reg
    always @(posedge CLK) begin
        // @Todo: isNop_IF_ID에 따른 noop 기능 추가
        INST_ID_EX <= INST_IF_ID;
    end
    //control signal
    always @(posedge CLK) begin
        regWrite_ID_EX <= regWrite;
        wbSel_ID_EX <= wbSel;
        memWrite_ID_EX <= memWrite;
        memByte_ID_EX <= memByte;
        
        alu_control_ID_EX <= alu_control;
        is_sign_ID_EX <= is_sign;
        imm_control_ID_EX <= imm_control;
        ASel_ID_EX <= ASel;
        BSel_ID_EX <= BSel;
    end
    

    /*EX datapath*/
    //alu_out
    always @(posedge CLK) begin
        alu_out <= alu_result;
    end
    //RF_RD2_EX_MEM
    always @(posedge CLK) begin
        RF_RD2_EX_MEM <= RF_RD1_ID_EX;
    end
    //pc_EX_MEM
    always @(posedge CLK) begin
        pc_EX_MEM <= pc_ID_EX;
    end
    //instruction reg
    always @(posedge CLK) begin
        INST_EX_MEM <= INST_MEM_WB;
    end
    //control signal
    always @(posedge CLK) begin
        regWrite_EX_MEM <= regWrite_ID_EX;
        wbSel_EX_MEM <= wbSel_ID_EX ;
        memWrite_EX_MEM <= memWrite_ID_EX;
        memByte_EX_MEM <= memByte_ID_EX;
    end

    /*MEM datapath*/
    //data memory connection
    assign D_MEM_ADDR = alu_out & 16'h3FFF;
    assign D_MEM_DOUT = RF_RD2_EX_MEM;
    assign D_MEM_WEN = memWrite_EX_MEM;
    //instruction reg
    always @(posedge CLK) begin
        INST_MEM_WB <= INST_EX_MEM;
    end

    always @(posedge CLK) begin
        if(wbSel_EX_MEM == 2'b00) begin
            RF_WD_MEM_WB <= alu_out; 
        end
        else if(wbSel_EX_MEM == 2'b01) begin
            RF_WD_MEM_WB <= D_MEM_DI;
        end
        else if(wbSel_EX_MEM == 2'b10) begin
            RF_WD_MEM_WB <= pc_EX_MEM + 4;
        end
    end
    //control signal
    always @(posedge CLK) begin
        regWrite_MEM_WB <= regWrite_EX_MEM;
    end

    /*WB datapath*/
    assign RF_WD = RF_WD_MEM_WB;
    assign RF_WA1 = INST_MEM_WB[11:7];
    assign RF_WE = regWrite_MEM_WB;

    
    //termination & output Port
	wire termination_flag = 0;
	reg termination_flag_reg;
	reg[6:0] opcode;
	reg HALT_reg;

	assign termination_flag = termination_flag_reg;
	assign HALT = HALT_reg;
	assign opcode = INST_IF_ID[6:0];

	always@(*) begin
		// 종료 조건 설정
		if(I_MEM_DI_reg == 32'h00c00093 ) begin
			termination_flag_reg = 1;
		end
		else begin
			if(I_MEM_DI_reg == 32'h00008067 && termination_flag_reg == 1) begin
				termination_flag_reg = 1;
			end
			else begin
				termination_flag_reg = 0;
			end
		end

		if(termination_flag_reg & (I_MEM_DI_reg == 32'h00008067)) begin
			HALT_reg = 1;
		end 
		else begin
			HALT_reg = 0;
		end
	end
endmodule //

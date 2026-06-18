
// SINGLE CYCLE RISC-V PROCESSOR (RV32I Core Subset)

// 1. Control Unit

module control_unit(
    input  [6:0] opcode,
    input  [2:0] funct3,
    input        funct7_bit, // funct7[5]
    output reg   RegWrite,
    output reg   ALUSrc,
    output reg   MemWrite,
    output reg   MemRead,
    output reg   MemToReg,
    output reg   Branch,
    output reg [3:0] ALUControl
);
    always @(*) begin
        // Defaults
        RegWrite   = 0; ALUSrc     = 0; MemWrite   = 0;
        MemRead    = 0; MemToReg   = 0; Branch     = 0;
        ALUControl = 4'b0000;

        case(opcode)
            7'b0110011: begin // R-type (add, sub)
                RegWrite = 1;
                if (funct7_bit && funct3 == 3'b000) 
                    ALUControl = 4'b0110; // sub
                else 
                    ALUControl = 4'b0010; // add
            end
            7'b0010011: begin // I-type ALU (addi)
                RegWrite   = 1;
                ALUSrc     = 1;
                ALUControl = 4'b0010; // add
            end
            7'b0000011: begin // Load (lw)
                RegWrite   = 1;
                ALUSrc     = 1;
                MemRead    = 1;
                MemToReg   = 1;
                ALUControl = 4'b0010; // address calculation (add)
            end
            7'b0100011: begin // Store (sw)
                ALUSrc     = 1;
                MemWrite   = 1;
                ALUControl = 4'b0010; // address calculation (add)
            end
            7'b1100011: begin // Branch (beq)
                Branch     = 1;
                ALUControl = 4'b0110; // sub (for equality comparison)
            end
            default: ;
        endcase
    end
endmodule


// 2. Register File

module register_file(
    input         clk,
    input         RegWrite,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [31:0] WD,
    output [31:0] RD1,
    output [31:0] RD2
);
    reg [31:0] registers [31:0];
    integer i;

    initial begin
        for(i = 0; i < 32; i = i + 1) registers[i] = 32'h0;
    end

    // Internal async read
    assign RD1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign RD2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

    // Synchronous write back
    always @(posedge clk) begin
        if (RegWrite && (rd != 5'b0)) begin
            registers[rd] <= WD;
        end
    end
endmodule


// 3. Immediate Generator

module imm_gen(
    input  [31:0] instr,
    output reg [31:0] imm
);
    always @(*) begin
        case(instr[6:0])
            7'b0010011: imm = {{20{instr[31]}}, instr[31:20]};                 // I-type
            7'b0000011: imm = {{20{instr[31]}}, instr[31:20]};                 // lw
            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};    // S-type (sw)
            7'b1100011: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type (beq)
            default:    imm = 32'h0;
        endcase
    end
endmodule


// 4. Arithmetic Logic Unit (ALU)

module alu(
    input  [31:0] A,
    input  [31:0] B,
    input  [3:0]  ALUControl,
    output reg [31:0] ALUResult,
    output        Zero
);
    always @(*) begin
        case(ALUControl)
            4'b0010: ALUResult = A + B;       // ADD
            4'b0110: ALUResult = A - B;       // SUB
            4'b0000: ALUResult = A & B;       // AND
            4'b0001: ALUResult = A | B;       // OR
            default: ALUResult = 32'h0;
        endcase
    end

    assign Zero = (ALUResult == 32'h0);
endmodule


// 5. Instruction Memory

module instruction_memory(
    input  [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem [63:0];

    initial begin
        $readmemh("instr_mem.hex", mem);
    end

    // Word aligned address reading (dividing by 4 via slicing)
    assign instr = mem[addr[7:2]]; 
endmodule


// 6. Data Memory

module data_memory(
    input         clk,
    input         MemWrite,
    input         MemRead,
    input  [31:0] addr,
    input  [31:0] write_data,
    output [31:0] read_data
);
    reg [31:0] ram [63:0];
    
    integer i;
    initial begin
        for(i = 0; i < 64; i = i + 1) ram[i] = 32'h0;
    end

    always @(posedge clk) begin
        if (MemWrite) begin
            ram[addr[7:2]] <= write_data;
        end
    end

    assign read_data = (MemRead) ? ram[addr[7:2]] : 32'h0;
endmodule


// TOP-LEVEL DATAPATH INTEGRATION

module riscv_single_cycle(
    input clk,
    input reset
);
    // Wire declarations
    reg  [31:0] PC;
    wire [31:0] next_PC, PC_plus_4, PC_branch;
    wire [31:0] instr;
    wire [31:0] reg_RD1, reg_RD2, reg_WD;
    wire [31:0] imm_ext;
    wire [31:0] alu_operand_B;
    wire [31:0] alu_result;
    wire [31:0] mem_read_data;
    wire        zero_flag;

    // Control signals
    wire RegWrite, ALUSrc, MemWrite, MemRead, MemToReg, Branch;
    wire [3:0] ALUControl;

    // PC Update Logic
    always @(posedge clk or posedge reset) begin
        if (reset)
            PC <= 32'h0;
        else
            PC <= next_PC;
    end

    // Branch Control Multiplexer
    assign PC_plus_4 = PC + 4;
    assign PC_branch = PC + imm_ext;
    assign next_PC   = (Branch && zero_flag) ? PC_branch : PC_plus_4;

    // Module Instantiations
    instruction_memory imem (
        .addr(PC),
        .instr(instr)
    );

    control_unit ctrl (
        .opcode(instr[6:0]),
        .funct3(instr[14:12]),
        .funct7_bit(instr[30]),
        .RegWrite(RegWrite),
        .ALUSrc(ALUSrc),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .MemToReg(MemToReg),
        .Branch(Branch),
        .ALUControl(ALUControl)
    );

    register_file regfile (
        .clk(clk),
        .RegWrite(RegWrite),
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .WD(reg_WD),
        .RD1(reg_RD1),
        .RD2(reg_RD2)
    );

    imm_gen ig (
        .instr(instr),
        .imm(imm_ext)
    );

    // ALU Source Multiplexer
    assign alu_operand_B = (ALUSrc) ? imm_ext : reg_RD2;

    alu execution_unit (
        .A(reg_RD1),
        .B(alu_operand_B),
        .ALUControl(ALUControl),
        .ALUResult(alu_result),
        .Zero(zero_flag)
    );

    data_memory dmem (
        .clk(clk),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .addr(alu_result),
        .write_data(reg_RD2),
        .read_data(mem_read_data)
    );

    // Memory To Register Multiplexer
    assign reg_WD = (MemToReg) ? mem_read_data : alu_result;

endmodule

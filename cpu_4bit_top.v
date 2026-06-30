// =====================================================================
// 4-bit CPU - Top Level
// Single-cycle, non-pipelined. See ISA.md for the instruction set.
//
// Instruction word (8 bits): [7:4] opcode
//   R-type  (opcode 0001-0111): [3:2] Rd   [1:0] Rs
//   M-type  (opcode 1000-1100): [3:0] addr / immediate   (operates on R0)
//   HALT    (opcode 1111)
// =====================================================================
module cpu_4bit_top (
    input  wire clk,
    input  wire rst,
    output wire [3:0] pc_out,
    output wire [7:0] instr_out,
    output wire [3:0] r0, r1, r2, r3,   // register debug outputs
    output wire        zflag_out,
    output wire        halted
);

    // -----------------------------------------------------------------
    // Program Counter
    // -----------------------------------------------------------------
    reg [3:0] pc;
    assign pc_out = pc;

    // -----------------------------------------------------------------
    // Instruction Memory (ROM) - the demo program (see ISA.md, program.asm)
    // Computes R1 * R2_initial via repeated addition and stores result
    // in data memory address 0.   (3 * 2 = 6)
    // -----------------------------------------------------------------
    reg [7:0] instr_mem [0:15];
    initial begin
        instr_mem[0]  = 8'h83; // LDI 3            -> R0 = 3
        instr_mem[1]  = 8'h74; // MOV R1,R0        -> R1 = 3
        instr_mem[2]  = 8'h82; // LDI 2            -> R0 = 2
        instr_mem[3]  = 8'h78; // MOV R2,R0        -> R2 = 2
        instr_mem[4]  = 8'h81; // LDI 1            -> R0 = 1
        instr_mem[5]  = 8'h7C; // MOV R3,R0        -> R3 = 1
        instr_mem[6]  = 8'h80; // LDI 0            -> R0 = 0 (accumulator reset)
        instr_mem[7]  = 8'h11; // LOOP: ADD R0,R1  -> R0 += R1
        instr_mem[8]  = 8'h2B; //       SUB R2,R3  -> R2 -= 1 (sets Z)
        instr_mem[9]  = 8'hBB; //       JZ 11      -> if Z, goto STORE
        instr_mem[10] = 8'hC7; //       JMP 7      -> else repeat loop
        instr_mem[11] = 8'hA0; // STORE 0          -> MEM[0] = R0
        instr_mem[12] = 8'hF0; // HALT
        instr_mem[13] = 8'h00;
        instr_mem[14] = 8'h00;
        instr_mem[15] = 8'h00;
    end

    wire [7:0] instr = instr_mem[pc];
    assign instr_out = instr;

    // -----------------------------------------------------------------
    // Instruction Decode
    // -----------------------------------------------------------------
    wire [3:0] opcode  = instr[7:4];
    wire [1:0] rd_addr = instr[3:2];
    wire [1:0] rs_addr = instr[1:0];
    wire [3:0] maddr   = instr[3:0];   // address/immediate for M-type & HALT

    wire is_rtype  = (opcode >= 4'b0001) && (opcode <= 4'b0111); // ADD..MOV
    wire is_ldi    = (opcode == 4'b1000);
    wire is_load   = (opcode == 4'b1001);
    wire is_store  = (opcode == 4'b1010);
    wire is_jz     = (opcode == 4'b1011);
    wire is_jmp    = (opcode == 4'b1100);
    wire is_halt   = (opcode == 4'b1111);
    wire is_nop    = (opcode == 4'b0000);

    // -----------------------------------------------------------------
    // Register File
    // -----------------------------------------------------------------
    wire [3:0] rf_rd_data, rf_rs_data;
    reg        rf_we;
    reg  [1:0] rf_waddr;
    reg  [3:0] rf_wdata;

    register_file_4bit RF (
        .clk(clk), .rst(rst), .we(rf_we),
        .rd_addr(is_rtype ? rd_addr : 2'b00),  // M-type/LDI/LOAD always target R0
        .rs_addr(rs_addr),
        .write_data(rf_wdata),
        .rd_data(rf_rd_data),
        .rs_data(rf_rs_data)
    );

    // debug taps - direct register snapshot for waveform/monitor visibility
    assign r0 = RF.regs[0];
    assign r1 = RF.regs[1];
    assign r2 = RF.regs[2];
    assign r3 = RF.regs[3];

    // -----------------------------------------------------------------
    // ALU
    // -----------------------------------------------------------------
    wire [3:0] alu_result;
    wire        alu_zero;

    alu_4bit ALU (
        .a(rf_rd_data),
        .b(rf_rs_data),
        .alu_op(opcode[2:0]),
        .result(alu_result),
        .zero(alu_zero)
    );

    // -----------------------------------------------------------------
    // Zero flag register (latched after R-type ALU ops)
    // -----------------------------------------------------------------
    reg zflag;
    assign zflag_out = zflag;

    // -----------------------------------------------------------------
    // Data Memory
    // -----------------------------------------------------------------
    wire [3:0] mem_read_data;
    reg        mem_we;

    data_memory_4bit DMEM (
        .clk(clk), .we(mem_we),
        .addr(maddr),
        .write_data(rf_rd_data),   // STORE always writes current R0 value
        .read_data(mem_read_data)
    );

    // -----------------------------------------------------------------
    // Halt latch
    // -----------------------------------------------------------------
    reg halt_reg;
    assign halted = halt_reg;

    // -----------------------------------------------------------------
    // Control Unit: combinational control signal generation
    // -----------------------------------------------------------------
    always @(*) begin
        rf_we    = 1'b0;
        rf_wdata = 4'b0000;
        mem_we   = 1'b0;

        if (!halt_reg) begin
            if (is_rtype) begin
                rf_we    = 1'b1;
                rf_wdata = alu_result;
            end else if (is_ldi) begin
                rf_we    = 1'b1;
                rf_wdata = maddr;          // immediate value
            end else if (is_load) begin
                rf_we    = 1'b1;
                rf_wdata = mem_read_data;
            end else if (is_store) begin
                mem_we   = 1'b1;
            end
            // JZ / JMP / HALT / NOP: no register or memory write
        end
    end

    // -----------------------------------------------------------------
    // Sequential: PC update + Z flag update
    // -----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pc       <= 4'b0000;
            zflag    <= 1'b0;
            halt_reg <= 1'b0;
        end else if (halt_reg) begin
            pc <= pc;  // frozen
        end else begin
            // next PC
            if (is_jz && zflag)
                pc <= maddr;
            else if (is_jmp)
                pc <= maddr;
            else
                pc <= pc + 1'b1;

            // zero flag updates only on R-type ALU ops
            if (is_rtype)
                zflag <= alu_zero;

            if (is_halt)
                halt_reg <= 1'b1;
        end
    end

endmodule

// =====================================================================
// 4-bit ALU
// alu_op directly reuses the instruction opcode[2:0] field for R-type
// instructions (ADD/SUB/AND/OR/XOR/NOT/MOV), see ISA.md for the mapping.
// =====================================================================
module alu_4bit (
    input  wire [3:0] a,        // Rd (current value)
    input  wire [3:0] b,        // Rs (current value)
    input  wire [2:0] alu_op,   // 001 ADD,010 SUB,011 AND,100 OR,101 XOR,110 NOT,111 MOV
    output reg  [3:0] result,
    output wire        zero      // 1 if result == 0
);
    localparam OP_ADD = 3'b001,
               OP_SUB = 3'b010,
               OP_AND = 3'b011,
               OP_OR  = 3'b100,
               OP_XOR = 3'b101,
               OP_NOT = 3'b110,
               OP_MOV = 3'b111;

    always @(*) begin
        case (alu_op)
            OP_ADD: result = a + b;
            OP_SUB: result = a - b;
            OP_AND: result = a & b;
            OP_OR : result = a | b;
            OP_XOR: result = a ^ b;
            OP_NOT: result = ~b;
            OP_MOV: result = b;
            default: result = 4'b0000;
        endcase
    end

    assign zero = (result == 4'b0000);

endmodule

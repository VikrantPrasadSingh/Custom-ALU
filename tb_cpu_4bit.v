`timescale 1ns/1ps
// =====================================================================
// Testbench: cpu_4bit_top
// Runs the built-in demo program (3 * 2 via repeated addition) and
// prints a full fetch-decode-execute trace each cycle.
// =====================================================================
module tb_cpu_4bit;

    reg clk = 0;
    reg rst;

    wire [3:0] pc;
    wire [7:0] instr;
    wire [3:0] r0, r1, r2, r3;
    wire        zflag;
    wire        halted;

    cpu_4bit_top DUT (
        .clk(clk), .rst(rst),
        .pc_out(pc), .instr_out(instr),
        .r0(r0), .r1(r1), .r2(r2), .r3(r3),
        .zflag_out(zflag), .halted(halted)
    );

    always #5 clk = ~clk;

    // simple mnemonic decoder for trace readability
    function [63:0] mnemonic(input [7:0] i);
        reg [3:0] op;
        begin
            op = i[7:4];
            case (op)
                4'b0000: mnemonic = "NOP     ";
                4'b0001: mnemonic = "ADD     ";
                4'b0010: mnemonic = "SUB     ";
                4'b0011: mnemonic = "AND     ";
                4'b0100: mnemonic = "OR      ";
                4'b0101: mnemonic = "XOR     ";
                4'b0110: mnemonic = "NOT     ";
                4'b0111: mnemonic = "MOV     ";
                4'b1000: mnemonic = "LDI     ";
                4'b1001: mnemonic = "LOAD    ";
                4'b1010: mnemonic = "STORE   ";
                4'b1011: mnemonic = "JZ      ";
                4'b1100: mnemonic = "JMP     ";
                4'b1111: mnemonic = "HALT    ";
                default: mnemonic = "????    ";
            endcase
        end
    endfunction

    initial begin
        $dumpfile("cpu_4bit.vcd");
        $dumpvars(0, tb_cpu_4bit);

        rst = 1;
        repeat (2) @(posedge clk);
        rst = 0;

        $display("PC | INSTR    MNEMONIC | R0 R1 R2 R3 | Z | HALT");
        $display("---+--------------------+-------------+---+-----");

        // run for enough cycles to complete the program, printing each cycle
        repeat (25) begin
            @(posedge clk);
            #1; // let combinational/registered values settle for display
            $display("%2d | %b  %s| %2d %2d %2d %2d |  %b |  %b",
                       pc, instr, mnemonic(instr), r0, r1, r2, r3, zflag, halted);
            if (halted) begin
                $display("\nCPU halted. Final R0=%0d  MEM[0]=%0d", r0, DUT.DMEM.mem[0]);
                $finish;
            end
        end

        $display("\nReached cycle limit without HALT - check program/control logic.");
        $finish;
    end

endmodule

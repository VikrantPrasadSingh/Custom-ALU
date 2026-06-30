// =====================================================================
// Register File: 4 general-purpose registers (R0-R3), 4 bits wide.
// Two asynchronous read ports (Rd, Rs), one synchronous write port.
// =====================================================================
module register_file_4bit (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,          // write enable
    input  wire [1:0]  rd_addr,     // destination/write address
    input  wire [1:0]  rs_addr,     // source read address
    input  wire [3:0]  write_data,
    output wire [3:0]  rd_data,     // current value at rd_addr (read before write)
    output wire [3:0]  rs_data      // current value at rs_addr
);
    reg [3:0] regs [0:3];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                regs[i] <= 4'b0000;
        end else if (we) begin
            regs[rd_addr] <= write_data;
        end
    end

    assign rd_data = regs[rd_addr];
    assign rs_data = regs[rs_addr];

endmodule

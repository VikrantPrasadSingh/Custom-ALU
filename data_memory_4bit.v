// =====================================================================
// Data Memory: 16 locations x 4 bits, byte... (nibble) addressable.
// Synchronous write, asynchronous (combinational) read.
// =====================================================================
module data_memory_4bit (
    input  wire        clk,
    input  wire        we,
    input  wire [3:0]  addr,
    input  wire [3:0]  write_data,
    output wire [3:0]  read_data
);
    reg [3:0] mem [0:15];
    integer i;

    initial begin
        for (i = 0; i < 16; i = i + 1)
            mem[i] = 4'b0000;
    end

    always @(posedge clk) begin
        if (we)
            mem[addr] <= write_data;
    end

    assign read_data = mem[addr];

endmodule

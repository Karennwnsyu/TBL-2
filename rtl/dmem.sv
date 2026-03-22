`timescale 1ns / 1ps

module dmem #(
    parameter logic [31:0] BASE_ADDR = 32'h0001_0000,
    parameter int unsigned BYTES     = 8192
) (
    input  logic        clk,
    input  logic        valid,
    input  logic        we,
    input  logic [3:0]  be,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,
    output logic        ready
);

    localparam int unsigned WORDS = BYTES / 4;

    logic [31:0] mem [0:WORDS-1];
    integer i;

    wire hit = (addr >= BASE_ADDR) && (addr < (BASE_ADDR + BYTES));
    wire [31:0] word_index = (addr - BASE_ADDR) >> 2;

    initial begin
        for (i = 0; i < WORDS; i++) begin
            mem[i] = 32'd0;
        end
    end

    assign ready = valid && hit;

    always_comb begin
        if (hit && (word_index < WORDS)) begin
            rdata = mem[word_index];
        end else begin
            rdata = 32'd0;
        end
    end

    always_ff @(posedge clk) begin
        if (valid && we && hit && (word_index < WORDS)) begin
            if (be[0]) mem[word_index][7:0]   <= wdata[7:0];
            if (be[1]) mem[word_index][15:8]  <= wdata[15:8];
            if (be[2]) mem[word_index][23:16] <= wdata[23:16];
            if (be[3]) mem[word_index][31:24] <= wdata[31:24];
        end
    end

endmodule

`timescale 1ns / 1ps

module imem #(
    parameter int unsigned WORDS   = 4096,
    parameter string       MEMFILE = "clock.mem"
) (
    input  logic [31:0] addr,
    output logic [31:0] rdata
);

    logic [31:0] mem [0:WORDS-1];
    integer i;

    initial begin
        for (i = 0; i < WORDS; i++) begin
            mem[i] = 32'h0000_0013; // NOP = addi x0, x0, 0
        end
        if (MEMFILE != "") begin
            $readmemh(MEMFILE, mem);
        end
    end

    always_comb begin
        if (addr[31:2] < WORDS) begin
            rdata = mem[addr[31:2]];
        end else begin
            rdata = 32'h0000_0013;
        end
    end

endmodule

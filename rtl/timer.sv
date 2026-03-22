`timescale 1ns / 1ps

module timer #(
    parameter int unsigned DEFAULT_PERIOD_CYCLES = 125_000_000,
    parameter logic [31:0] BASE_ADDR             = 32'h4000_0010
) (
    input  logic        clk,
    input  logic        rst,

    input  logic        bus_valid,
    input  logic        bus_we,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_wdata,
    output logic [31:0] bus_rdata,
    output logic        bus_ready
);

    logic [31:0] counter;
    logic        tick_pending;

    // Absolute addresses: STATUS @ BASE, VALUE @ BASE+4
    logic is_status, is_value;
    assign is_status = (bus_addr == BASE_ADDR);
    assign is_value  = (bus_addr == BASE_ADDR + 32'd4);

    always_ff @(posedge clk) begin
        if (rst) begin
            counter      <= 32'd0;
            tick_pending <= 1'b0;
        end else begin
            if (counter == DEFAULT_PERIOD_CYCLES - 1) begin
                counter      <= 32'd0;
                tick_pending <= 1'b1;
            end else begin
                counter <= counter + 1;
            end

            if (bus_valid && bus_we && is_status && !bus_ready && bus_wdata[0])
                tick_pending <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            bus_ready <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            bus_ready <= 1'b0;
            bus_rdata <= 32'd0;

            if (bus_valid && !bus_ready) begin
                bus_ready <= 1'b1;
                if (!bus_we) begin
                    if (is_status)
                        bus_rdata <= {31'd0, tick_pending};
                    else if (is_value)
                        bus_rdata <= counter;
                end
            end
        end
    end

endmodule

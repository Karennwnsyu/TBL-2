`timescale 1ns / 1ps

module timer #(
    parameter int unsigned DEFAULT_PERIOD_CYCLES = 125_000_000
) (
    input  logic        clk,
    input  logic        rst,
    
    // Memory-mapped I/O Bus
    input  logic        bus_valid,
    input  logic        bus_we,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_wdata,
    output logic [31:0] bus_rdata,
    output logic        bus_ready
);

    logic [31:0] counter;
    logic        tick_pending;
    
    // Register Address Decode
    // 0x00: STATUS (Read: bit 0 is tick_pending, Write 1 to clear)
    // 0x04: VALUE (Read-only: current counter tick value)
    logic is_status, is_value;
    assign is_status = (bus_addr[7:0] == 8'h00);
    assign is_value  = (bus_addr[7:0] == 8'h04);

    // Counter logic
    always_ff @(posedge clk) begin
        if (rst) begin
            counter <= 32'd0;
            tick_pending <= 1'b0;
        end else begin
            // Increment counter
            if (counter == DEFAULT_PERIOD_CYCLES - 1) begin
                counter <= 32'd0;
                tick_pending <= 1'b1;
            end else begin
                counter <= counter + 1;
            end
            
            // Handle W1C (Write 1 to Clear) from bus
            if (bus_valid && bus_we && is_status && !bus_ready) begin
                if (bus_wdata[0]) begin
                    tick_pending <= 1'b0;
                end
            end
        end
    end

    // Bus Interface logic
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
                    if (is_status) begin
                        bus_rdata <= {31'd0, tick_pending};
                    end else if (is_value) begin
                        bus_rdata <= counter;
                    end
                end
            end
        end
    end

endmodule

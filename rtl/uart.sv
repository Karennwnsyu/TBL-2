`timescale 1ns / 1ps

module uart #(
    parameter int unsigned CLK_HZ = 125_000_000,
    parameter int unsigned BAUD   = 115_200
) (
    input  logic        clk,
    input  logic        rst,
    
    // Memory-mapped I/O Bus
    input  logic        bus_valid,
    input  logic        bus_we,
    input  logic [31:0] bus_addr,
    input  logic [31:0] bus_wdata,
    output logic [31:0] bus_rdata,
    output logic        bus_ready,
    
    // UART signals
    input  logic        rx, // Optional/Unused in basic requirements
    output logic        tx
);

    localparam int unsigned CYCLES_PER_BIT = CLK_HZ / BAUD;
    
    // Registers
    logic [7:0] tx_data_reg;
    logic       tx_ready;
    
    // TX State Machine
    typedef enum logic [1:0] { IDLE, START, DATA, STOP } state_t;
    state_t state, next_state;
    
    logic [31:0] cycle_cnt;
    logic [2:0]  bit_cnt;
    
    // Register Address Decode
    // 0x00: TXDATA (Write starts transmission)
    // 0x04: STATUS (Read: bit 0 is tx_ready)
    logic is_txdata, is_status;
    assign is_txdata = (bus_addr[7:0] == 8'h00);
    assign is_status = (bus_addr[7:0] == 8'h04);
    
    // Bus Interface
    always_ff @(posedge clk) begin
        if (rst) begin
            bus_ready <= 1'b0;
            bus_rdata <= 32'd0;
        end else begin
            bus_ready <= 1'b0;
            bus_rdata <= 32'd0;
            
            if (bus_valid && !bus_ready) begin
                bus_ready <= 1'b1;
                
                if (bus_we) begin
                    if (is_txdata && tx_ready) begin
                        // Load data and trigger FSM
                        // FSM will catch this next cycle because tx_ready will drop
                    end
                end else begin
                    if (is_status) begin
                        bus_rdata <= {31'd0, tx_ready};
                    end
                end
            end
        end
    end
    
    // TX FSM
    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1;
            tx_ready  <= 1'b1;
            cycle_cnt <= 32'd0;
            bit_cnt   <= 3'd0;
            tx_data_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (bus_valid && bus_we && is_txdata && tx_ready && !bus_ready) begin
                        tx_data_reg <= bus_wdata[7:0];
                        tx_ready    <= 1'b0;
                        state       <= START;
                        cycle_cnt   <= 32'd0;
                    end else begin
                        tx_ready    <= 1'b1;
                    end
                end
                
                START: begin
                    tx <= 1'b0;
                    if (cycle_cnt == CYCLES_PER_BIT - 1) begin
                        cycle_cnt <= 32'd0;
                        state     <= DATA;
                        bit_cnt   <= 3'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end
                
                DATA: begin
                    tx <= tx_data_reg[0];
                    if (cycle_cnt == CYCLES_PER_BIT - 1) begin
                        cycle_cnt <= 32'd0;
                        tx_data_reg <= {1'b0, tx_data_reg[7:1]};
                        if (bit_cnt == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end
                
                STOP: begin
                    tx <= 1'b1;
                    if (cycle_cnt == CYCLES_PER_BIT - 1) begin
                        cycle_cnt <= 32'd0;
                        state     <= IDLE;
                        tx_ready  <= 1'b1;
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end
            endcase
        end
    end

endmodule

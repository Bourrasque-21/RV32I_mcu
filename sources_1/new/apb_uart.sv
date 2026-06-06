`timescale 1ns / 1ps

module apb_uart (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    input               uart_rx,
    output              uart_tx,
    output logic        PREADY,
    output logic [31:0] PRDATA,
    output logic        interrupt_signal,
    input               interrupt_clear
);

    localparam [11:0] BAUD_ADDR = 12'h0000;
    localparam [11:0] STATUS_ADDR = 12'h0004;
    localparam [11:0] TXDATA_ADDR = 12'h0008;
    localparam [11:0] RXDATA_ADDR = 12'h000c;

    logic        w_b_tick;
    logic [ 1:0] w_baud_set;
    logic        w_rx_done;
    logic [ 7:0] w_rx_data;
    logic        w_tx_busy;
    logic        w_tx_done;
    logic        w_tx_start;

    logic [31:0] status_data;
    logic [ 7:0] rx_data_reg;
    logic [ 7:0] tx_data_reg;
    logic [31:0] baudset_reg;
    logic        rx_valid_reg;

    assign interrupt_signal = rx_valid_reg;
    assign PREADY = PENABLE & PSEL;
    assign w_baud_set = baudset_reg[1:0];
    assign w_tx_start = PREADY & PWRITE & (PADDR[11:0] == TXDATA_ADDR) & ~w_tx_busy;

    assign status_data = {rx_valid_reg, 30'd0, w_tx_busy};

    always_comb begin
        PRDATA = 32'h0000_0000;
        if (PREADY) begin
            case (PADDR[11:0])
                BAUD_ADDR:   PRDATA = baudset_reg;
                TXDATA_ADDR: PRDATA = {24'h0, tx_data_reg};
                STATUS_ADDR: PRDATA = status_data;
                RXDATA_ADDR: PRDATA = {24'h0, rx_data_reg};
                default:     PRDATA = 32'h0000_0000;
            endcase
        end
    end

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            baudset_reg <= 32'h0;
            rx_data_reg <= 8'h0;
            tx_data_reg <= 8'h0;
            rx_valid_reg <= 1'b0;
        end else begin
            if (interrupt_clear) begin
                rx_valid_reg <= 1'b0;
            end
            if (PREADY & ~PWRITE & (PADDR[11:0] == RXDATA_ADDR)) begin
                rx_valid_reg <= 1'b0;
            end
            if (w_rx_done) begin
                rx_data_reg <= w_rx_data;
                rx_valid_reg <= 1'b1;
            end
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    BAUD_ADDR:   baudset_reg <= PWDATA;
                    TXDATA_ADDR: begin
                        if (~w_tx_busy) begin
                            tx_data_reg <= PWDATA[7:0];
                        end
                    end
                endcase
            end
        end
    end

    uart_tx U_UART_TX (
        .clk     (PCLK),
        .rst     (PRESET),
        .tx_start(w_tx_start),
        .b_tick  (w_b_tick),
        .tx_data (PWDATA[7:0]),
        .tx_busy (w_tx_busy),
        .tx_done (w_tx_done),
        .uart_tx (uart_tx)
    );

    uart_rx U_UART_RX (
        .clk    (PCLK),
        .rst    (PRESET),
        .rx     (uart_rx),
        .b_tick (w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    baud_tick U_BAUD_TICK (
        .clk     (PCLK),
        .rst     (PRESET),
        .baud_sel(w_baud_set),
        .b_tick  (w_b_tick)
    );

endmodule

`timescale 1ns / 1ps

module rv32i_mcu (
    input               clk,
    input               rst,
    input  logic [ 7:0] sw,
    input               uart_rx,
    output              uart_tx,
    output logic [ 7:0] led,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data,
    inout  logic [15:0] GPIO
);

    logic [31:0]
        instr_addr,
        instr_data,
        bus_addr,
        bus_wdata,
        bus_rdata,
        apb_rdata,
        ram_rdata,
        w_paddr,
        w_pwdata;
    logic [2:0] funct3_out;
    logic
        bus_wreq,
        bus_rreq,
        bus_ready,
        apb_ready,
        ram_ready,
        w_penable,
        w_pwrite;
    logic ram_wreq, ram_rreq, apb_wreq, apb_rreq;
    logic uart_interrupt_signal, uart_interrupt_clear;

    logic w_psel0, w_psel1, w_psel2, w_psel3, w_psel4, w_psel5;
    logic [31:0]
        w_prdata0, w_prdata1, w_prdata2, w_prdata3, w_prdata4, w_prdata5;
    logic w_pready0, w_pready1, w_pready2, w_pready3, w_pready4, w_pready5;

    assign w_prdata0 = 32'h0000_0000;
    assign w_pready0 = 1'b0;

    instruction_mem U_INSTRUCTION_MEM (.*);

    rv32i_cpu U_RV32I (
        .clk             (clk),
        .rst             (rst),
        .instr_data      (instr_data),
        .bus_rdata       (bus_rdata),
        .bus_ready       (bus_ready),
        .interrupt_signal(uart_interrupt_signal),
        .instr_addr      (instr_addr),
        .bus_wreq        (bus_wreq),
        .bus_rreq        (bus_rreq),
        .bus_addr        (bus_addr),
        .bus_wdata       (bus_wdata),
        .funct3_out      (funct3_out),
        .interrupt_clear (uart_interrupt_clear)
    );

    bus_router U_BUS_ROUTER (
        .bus_addr (bus_addr),
        .bus_wreq (bus_wreq),
        .bus_rreq (bus_rreq),
        .ram_rdata(ram_rdata),
        .ram_ready(ram_ready),
        .apb_rdata(apb_rdata),
        .apb_ready(apb_ready),
        .ram_wreq (ram_wreq),
        .ram_rreq (ram_rreq),
        .apb_wreq (apb_wreq),
        .apb_rreq (apb_rreq),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready)
    );

    APB_Master U_APB_MASTER (
        .PCLK  (clk),
        .PRESET(rst),
        .Addr  (bus_addr),
        .Wdata (bus_wdata),
        .WREQ  (apb_wreq),
        .RREQ  (apb_rreq),
        .Rdata (apb_rdata),
        .Ready (apb_ready),

        .PADDR  (w_paddr),
        .PWDATA (w_pwdata),
        .PENABLE(w_penable),
        .PWRITE (w_pwrite),
        // from APB SLAVE
        .PSEL0  (w_psel0),
        .PSEL1  (w_psel1),
        .PSEL2  (w_psel2),
        .PSEL3  (w_psel3),
        .PSEL4  (w_psel4),
        .PSEL5  (w_psel5),
        .PRDATA0(w_prdata0),
        .PRDATA1(w_prdata1),
        .PRDATA2(w_prdata2),
        .PRDATA3(w_prdata3),
        .PRDATA4(w_prdata4),
        .PRDATA5(w_prdata5),
        .PREADY0(w_pready0),
        .PREADY1(w_pready1),
        .PREADY2(w_pready2),
        .PREADY3(w_pready3),
        .PREADY4(w_pready4),
        .PREADY5(w_pready5)
    );

    data_dmem U_RAM (
        .clk      (clk),
        .mem_read (ram_rreq),
        .mem_write(ram_wreq),
        .i_funct3 (funct3_out),
        .addr     (bus_addr),
        .wdata    (bus_wdata),
        .ready    (ram_ready),
        .rdata    (ram_rdata)
    );

    APB_GPO U_APB_GPO01 (
        .PCLK   (clk),
        .PRESET (rst),
        .PADDR  (w_paddr),
        .PWDATA (w_pwdata),
        .PENABLE(w_penable),
        .PWRITE (w_pwrite),
        .PSEL   (w_psel1),
        .PREADY (w_pready1),
        .PRDATA  (w_prdata1),
        .GPO_OUT (led)
    );

    APB_GPI U_APB_GPI02 (
        .PCLK   (clk),
        .PRESET (rst),
        .PADDR  (w_paddr),
        .PENABLE(w_penable),
        .PSEL   (w_psel2),
        .PREADY (w_pready2),
        .PRDATA (w_prdata2),
        .PWRITE (w_pwrite),
        .PWDATA (w_pwdata),
        .GPI    (sw)
    );

    APB_GPIO U_APB_GPIO (
        .PCLK   (clk),
        .PRESET (rst),
        .PADDR  (w_paddr),
        .PWDATA (w_pwdata),
        .PENABLE(w_penable),
        .PWRITE (w_pwrite),
        .PSEL   (w_psel3),
        .PREADY (w_pready3),
        .PRDATA (w_prdata3),
        .GPIO   (GPIO)
    );

    APB_FND U_APB_FND (
        .PCLK     (clk),
        .PRESET   (rst),
        .PADDR    (w_paddr),
        .PWDATA   (w_pwdata),
        .PENABLE  (w_penable),
        .PWRITE   (w_pwrite),
        .PSEL     (w_psel4),
        .PREADY   (w_pready4),
        .PRDATA   (w_prdata4),
        .FND_DIGIT(fnd_digit),
        .FND_DATA (fnd_data)
    );

    apb_uart U_APB_UART (
        .PCLK            (clk),
        .PRESET          (rst),
        .PADDR           (w_paddr),
        .PWDATA          (w_pwdata),
        .PENABLE         (w_penable),
        .PWRITE          (w_pwrite),
        .PSEL            (w_psel5),
        .uart_rx         (uart_rx),
        .uart_tx         (uart_tx),
        .PREADY          (w_pready5),
        .PRDATA          (w_prdata5),
        .interrupt_signal(uart_interrupt_signal),
        .interrupt_clear (uart_interrupt_clear)
    );


endmodule

module bus_router (
    input        [31:0] bus_addr,
    input               bus_wreq,
    input               bus_rreq,
    input        [31:0] ram_rdata,
    input               ram_ready,
    input        [31:0] apb_rdata,
    input               apb_ready,
    output logic        ram_wreq,
    output logic        ram_rreq,
    output logic        apb_wreq,
    output logic        apb_rreq,
    output logic [31:0] bus_rdata,
    output logic        bus_ready
);

    logic ram_sel;

    always_comb begin
        ram_sel   = (bus_addr[31:28] == 4'h1);
        ram_wreq  = ram_sel & bus_wreq;
        ram_rreq  = ram_sel & bus_rreq;
        apb_wreq  = ~ram_sel & bus_wreq;
        apb_rreq  = ~ram_sel & bus_rreq;
        bus_rdata = ram_sel ? ram_rdata : apb_rdata;
        bus_ready = ram_sel ? ram_ready : apb_ready;
    end

endmodule

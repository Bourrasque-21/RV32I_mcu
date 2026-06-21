`timescale 1ns / 1ps

module APB_Master (
    // BUS Global signal
    input PCLK,
    input PRESET,

    // SoC Internal signal with CPU
    input        [31:0] Addr,   //from CPU
    input        [31:0] Wdata,  //from CPU
    input               WREQ,   //from CPU, signal CPU : dwe
    input               RREQ,   //from CPU, signal CPU : dre
    // output        SlaverR,
    output logic [31:0] Rdata,
    output logic        Ready,

    // APB Interface signal
    output logic [31:0] PADDR,
    output logic [31:0] PWDATA,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic        PSEL0,    // RAM
    output logic        PSEL1,    // GPO
    output logic        PSEL2,    // GPI
    output logic        PSEL3,    // GPIO
    output logic        PSEL4,    // FND
    output logic        PSEL5,    // UART
    input        [31:0] PRDATA0,  // from RAM
    input        [31:0] PRDATA1,  // from GPO
    input        [31:0] PRDATA2,  // from GPI
    input        [31:0] PRDATA3,  // from GPIO
    input        [31:0] PRDATA4,  // from FND
    input        [31:0] PRDATA5,  // from UART
    input               PREADY0,  // from RAM
    input               PREADY1,  // from GPO
    input               PREADY2,  // from GPI
    input               PREADY3,  // from GPIO
    input               PREADY4,  // from FND
    input               PREADY5   // from UART
);

    typedef enum {
        IDLE,
        SETUP,
        ACCESS
    } apb_state_e;
    apb_state_e c_state, n_state;

    logic [31:0] PADDR_next, PWDATA_next;
    logic decode_en, PWRITE_next;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin  // active-high reset
            c_state <= IDLE;
            PADDR   <= 32'h0;
            PWDATA  <= 32'h0;
            PWRITE  <= 1'b0;
        end else begin
            c_state <= n_state;
            PADDR   <= PADDR_next;
            PWDATA  <= PWDATA_next;
            PWRITE  <= PWRITE_next;
        end
    end

    // next
    always_comb begin
        decode_en   = 1'b0;
        PENABLE     = 1'b0;
        PADDR_next  = PADDR;
        PWDATA_next = PWDATA;
        PWRITE_next = PWRITE;
        n_state     = c_state;
        case (c_state)
            IDLE: begin
                decode_en   = 1'b0;
                PENABLE     = 1'b0;
                PADDR_next  = 32'h0;
                PWDATA_next = 32'h0;
                PWRITE_next = 1'b0;
                if (WREQ | RREQ) begin
                    PADDR_next  = Addr;
                    PWDATA_next = Wdata;
                    if (WREQ) begin
                        PWRITE_next = 1'b1;
                    end else begin
                        PWRITE_next = 1'b0;
                    end
                    n_state = SETUP;
                end
            end
            SETUP: begin
                decode_en = 1'b1;
                PENABLE   = 1'b0;
                n_state   = ACCESS;
            end
            ACCESS: begin
                decode_en = 1'b1;
                PENABLE   = 1'b1;
                if (Ready) begin
                    n_state = IDLE;
                end
            end
        endcase
    end

    address_decoder U_ADDRESS_DECODER (
        .en   (decode_en),
        .addr (PADDR),
        .psel0(PSEL0),
        .psel1(PSEL1),
        .psel2(PSEL2),
        .psel3(PSEL3),
        .psel4(PSEL4),
        .psel5(PSEL5)
    );

    apb_mux U_APB_MUX (
        .sel    (PADDR),
        .PRDATA0(PRDATA0),
        .PRDATA1(PRDATA1),
        .PRDATA2(PRDATA2),
        .PRDATA3(PRDATA3),
        .PRDATA4(PRDATA4),
        .PRDATA5(PRDATA5),
        .PREADY0(PREADY0),
        .PREADY1(PREADY1),
        .PREADY2(PREADY2),
        .PREADY3(PREADY3),
        .PREADY4(PREADY4),
        .PREADY5(PREADY5),
        .Rdata  (Rdata),
        .Ready  (Ready)
    );

endmodule


module address_decoder (
    input               en,
    input        [31:0] addr,
    output logic        psel0,
    output logic        psel1,
    output logic        psel2,
    output logic        psel3,
    output logic        psel4,
    output logic        psel5
);

    always_comb begin
        psel0 = 1'b0;  // idel : 0
        psel1 = 1'b0;  // idel : 0
        psel2 = 1'b0;  // idel : 0
        psel3 = 1'b0;  // idel : 0
        psel4 = 1'b0;  // idel : 0
        psel5 = 1'b0;  // idel : 0

        if (en) begin
            if (addr[31:28] == 4'h2) begin
                case (addr[15:12])
                    4'h0: psel1 = 1'b1;
                    4'h1: psel2 = 1'b1;
                    4'h2: psel3 = 1'b1;
                    4'h3: psel4 = 1'b1;
                    4'h4: psel5 = 1'b1;
                endcase
            end
        end
    end

endmodule


module apb_mux (
    input        [31:0] sel,
    input        [31:0] PRDATA0,
    input        [31:0] PRDATA1,
    input        [31:0] PRDATA2,
    input        [31:0] PRDATA3,
    input        [31:0] PRDATA4,
    input        [31:0] PRDATA5,
    input               PREADY0,
    input               PREADY1,
    input               PREADY2,
    input               PREADY3,
    input               PREADY4,
    input               PREADY5,
    output logic [31:0] Rdata,
    output logic        Ready
);

    always_comb begin
        Rdata = 32'h0000_0000;
        Ready = 1'b0;
        if (sel[31:28] == 4'h2) begin
            case (sel[15:12])
                4'h0: begin
                    Rdata = PRDATA1;
                    Ready = PREADY1;
                end
                4'h1: begin
                    Rdata = PRDATA2;
                    Ready = PREADY2;
                end
                4'h2: begin
                    Rdata = PRDATA3;
                    Ready = PREADY3;
                end
                4'h3: begin
                    Rdata = PRDATA4;
                    Ready = PREADY4;
                end
                4'h4: begin
                    Rdata = PRDATA5;
                    Ready = PREADY5;
                end
                default: begin
                    Rdata = 32'hxxxx_xxxx;
                    Ready = 1'bx;
                end
            endcase
        end
    end

endmodule

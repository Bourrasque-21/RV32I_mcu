`timescale 1ns / 1ps

module APB_GPI (
    input               PCLK,
    input               PRESET,
    input        [31:0] PADDR,
    input               PENABLE,
    input               PWRITE,
    input        [31:0] PWDATA,
    input  logic [ 7:0] GPI,
    input               PSEL,
    output logic        PREADY,
    output logic [31:0] PRDATA
);

    localparam [11:0] GPI_CTL_ADDR   = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;

    logic [7:0] GPI_IDATA_REG, GPI_CTL_REG;

    assign PREADY = PENABLE & PSEL;

    assign PRDATA = (PADDR[11:0] == GPI_CTL_ADDR)   ? {24'h000000, GPI_CTL_REG} :
                    (PADDR[11:0] == GPI_IDATA_ADDR) ? {24'h000000, GPI_IDATA_REG} :
                                                      32'h0000_0000;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPI_CTL_REG <= 8'h00;
        end else begin
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    GPI_CTL_ADDR: GPI_CTL_REG <= PWDATA[7:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign GPI_IDATA_REG[i] = GPI_CTL_REG[i] ? GPI[i] : 1'b0;
        end
    endgenerate

endmodule

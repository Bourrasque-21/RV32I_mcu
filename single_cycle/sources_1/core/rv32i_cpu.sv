`timescale 1ns / 1ps
`include "_define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] drdata,
    output [31:0] instr_addr,
    output [31:0] daddr,
    output [31:0] d_wdata,
    output [ 2:0] funct3_out,
    output        dwe
);

    logic rf_we, alu_mux_sel, branch_c, jal_c, jalr_c, raw_dwe;
    logic [2:0] w_rfwd_src;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .funct7     (instr_data[31:25]),
        .funct3     (instr_data[14:12]),
        .opcode     (instr_data[6:0]),
        .rf_we      (rf_we),
        .alusrc     (alu_mux_sel),
        .alu_control(alu_control),
        .rfwd_src   (w_rfwd_src),
        .funct3_out (funct3_out),
        .dwe        (raw_dwe),
        .branch_c   (branch_c),
        .jal_c      (jal_c),
        .jalr_c     (jalr_c)
    );

    // Prevent stores from firing while reset is asserted.
    assign dwe = raw_dwe & ~rst;

    datapath U_DATAPATH (
        .clk        (clk),
        .rst        (rst),
        .alu_control(alu_control),
        .instr_data (instr_data),
        .rf_we      (rf_we),
        .alusrc     (alu_mux_sel),
        .daddr      (daddr),
        .d_wdata    (d_wdata),
        .instr_addr (instr_addr),
        .rfwd_src   (w_rfwd_src),
        .branch_c   (branch_c),
        .drdata     (drdata),
        .jal_c      (jal_c),
        .jalr_c     (jalr_c)
    );

endmodule


module control_unit (
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    output logic       branch_c,
    output logic       jal_c,
    output logic       jalr_c,
    output logic       rf_we,
    output logic       alusrc,
    output logic       dwe,
    output logic [2:0] funct3_out,
    output logic [2:0] rfwd_src,
    output logic [3:0] alu_control
);

    always_comb begin
        rf_we       = 1'b0;
        alusrc      = 1'b0;
        alu_control = `ADD;
        dwe         = 1'b0;
        funct3_out  = 3'b0;
        rfwd_src    = 3'b0;
        branch_c    = 1'b0;
        jal_c       = 1'b0;
        jalr_c      = 1'b0;
        unique case (opcode)
            `R_TYPE: begin
                rf_we      = 1'b1;
                alusrc     = 1'b0;
                dwe        = 1'b0;
                funct3_out = 3'b0;
                rfwd_src   = 3'b0;
                branch_c   = 1'b0;
                jal_c      = 1'b0;
                jalr_c     = 1'b0;
                unique case ({funct7, funct3})
                    {7'b0000000, 3'b000}: alu_control = `ADD;
                    {7'b0100000, 3'b000}: alu_control = `SUB;
                    {7'b0000000, 3'b001}: alu_control = `SLL;
                    {7'b0000000, 3'b010}: alu_control = `SLT;
                    {7'b0000000, 3'b011}: alu_control = `SLTU;
                    {7'b0000000, 3'b100}: alu_control = `XOR;
                    {7'b0000000, 3'b101}: alu_control = `SRL;
                    {7'b0100000, 3'b101}: alu_control = `SRA;
                    {7'b0000000, 3'b110}: alu_control = `OR;
                    {7'b0000000, 3'b111}: alu_control = `AND;
                endcase
            end
            `S_TYPE: begin
                rf_we       = 1'b0;
                alusrc      = 1'b1;
                alu_control = `ADD;
                dwe         = 1'b1;
                funct3_out  = funct3;
                rfwd_src    = 3'b0;
                branch_c    = 1'b0;
                jal_c       = 1'b0;
                jalr_c      = 1'b0;
            end
            `IL_TYPE: begin
                rf_we       = 1'b1;
                alusrc      = 1'b1;
                alu_control = `ADD;
                dwe         = 1'b0;
                funct3_out  = funct3;
                rfwd_src    = 3'b001;
                branch_c    = 1'b0;
                jal_c       = 1'b0;
                jalr_c      = 1'b0;
            end
            `I_TYPE: begin
                rf_we      = 1'b1;
                alusrc     = 1'b1;
                dwe        = 1'b0;
                funct3_out = funct3;
                rfwd_src   = 3'b0;
                branch_c   = 1'b0;
                jal_c      = 1'b0;
                jalr_c     = 1'b0;
                if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                else alu_control = {1'b0, funct3};
            end
            `B_TYPE: begin
                rf_we       = 1'b0;
                alusrc      = 1'b0;
                dwe         = 1'b0;
                funct3_out  = funct3;
                rfwd_src    = 3'b0;
                branch_c    = 1'b1;
                jal_c       = 1'b0;
                jalr_c      = 1'b0;
                alu_control = {1'b0, funct3};
            end
            `LUI_TYPE: begin
                rf_we       = 1'b1;
                alusrc      = 1'b0;
                alu_control = `ADD;
                dwe         = 1'b0;
                funct3_out  = funct3;
                rfwd_src    = 3'b010;
                branch_c    = 1'b0;
                jal_c       = 1'b0;
                jalr_c      = 1'b0;
            end
            `AUIPC_TYPE: begin
                rf_we       = 1'b1;
                alusrc      = 1'b0;
                alu_control = `ADD;
                dwe         = 1'b0;
                funct3_out  = funct3;
                rfwd_src    = 3'b011;
                branch_c    = 1'b0;
                jal_c       = 1'b0;
                jalr_c      = 1'b0;
            end
            `JAL_TYPE: begin
                rf_we       = 1'b1;
                alusrc      = 1'b0;
                alu_control = `ADD;
                dwe         = 1'b0;
                funct3_out  = funct3;
                rfwd_src    = 3'b100;
                branch_c    = 1'b0;
                jal_c       = 1'b1;
                jalr_c      = 1'b0;
            end
            `JALR_TYPE: begin
                rf_we       = 1'b1;
                alusrc      = 1'b1;
                alu_control = `ADD;
                dwe         = 1'b0;
                funct3_out  = funct3;
                rfwd_src    = 3'b100;
                branch_c    = 1'b0;
                jal_c       = 1'b0;
                jalr_c      = 1'b1;
            end
        endcase
    end
endmodule

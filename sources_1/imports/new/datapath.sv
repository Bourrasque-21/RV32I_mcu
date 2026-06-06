`timescale 1ns / 1ps
`include "_define.vh"

module datapath (
    input               clk,
    input               rst,
    input               pc_en,
    input               ir_en,
    input               oldpc_en,
    input               operand_en,
    input               alu_out_en,
    input               mdr_en,
    input        [ 3:0] alu_control,
    input        [31:0] instr_data,
    input               rf_we,
    input               alusrc,
    input        [ 2:0] rfwd_src,
    input               branch_c,
    input               jal_c,
    input               jalr_c,
    input               save_return_addr,
    input               pc_sel_int,
    input        [31:0] bus_rdata,
    output logic [31:0] bus_addr,
    output logic [31:0] bus_wdata,
    output logic [31:0] instr_addr,
    output logic [31:0] ir_data,
    output logic        out_comp_result
);

    logic [31:0]
        rd1,
        rd2,
        out_old_pc,
        out_rd1,
        out_rd2,
        out_imm_data,
        out_alu_result,
        out_mdr_data,
        alu_result,
        alu_mux_out,
        imm_data,
        dmem_data_result,
        regfile_wdata,
        pc4_sum,
        normal_pc_next,
        old_pc4_sum,
        pc_rel_sum,
        pc_final_addr,
        pc_base_addr,
        pc_jump_addr;
    logic comp_result, branch_taken, branch_x_jal;
    logic        regfile_we;
    logic [ 4:0] regfile_wa;
    localparam [31:0] IRQ_VECTOR = 32'h0000_0040;
    localparam [4:0] RETURN_ADDR_REG = 5'd26;

    assign out_comp_result = comp_result;
    assign bus_addr = out_alu_result;
    assign bus_wdata = out_rd2;
    assign branch_taken = branch_c & comp_result;
    assign branch_x_jal = branch_taken | jal_c | jalr_c;
    assign pc_base_addr = (jalr_c) ? out_rd1 : out_old_pc;
    assign pc_jump_addr = (jalr_c) ? {pc_rel_sum[31:1], 1'b0} : pc_rel_sum;
    assign normal_pc_next = branch_x_jal ? pc_jump_addr : pc4_sum;
    assign regfile_we = save_return_addr | rf_we;
    assign regfile_wa = save_return_addr ? RETURN_ADDR_REG : ir_data[11:7];
    assign regfile_wdata = save_return_addr ? instr_addr : dmem_data_result;

    always_comb begin
        if (pc_sel_int) begin
            pc_final_addr = IRQ_VECTOR;
        end else begin
            pc_final_addr = normal_pc_next;
        end
    end

    pc U_PC (
        .clk       (clk),
        .rst       (rst),
        .pc_en     (pc_en),
        .address   (pc_final_addr),
        .instr_addr(instr_addr)
    );

    register_en U_IR_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (ir_en),
        .data_in (instr_data),
        .data_out(ir_data)
    );

    register_en U_OLD_PC_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (oldpc_en),
        .data_in (instr_addr),
        .data_out(out_old_pc)
    );

    adder U_PC_4_ADDER (
        .a(instr_addr),
        .b(32'd4),
        .s(pc4_sum)
    );

    adder U_OLD_PC_4_ADDER (
        .a(out_old_pc),
        .b(32'd4),
        .s(old_pc4_sum)
    );

    adder U_PC_REL_ADDER (
        .a(out_imm_data),
        .b(pc_base_addr),
        .s(pc_rel_sum)
    );

    register_file U_REG_FILE (
        .clk  (clk),
        .rst  (rst),
        .RA1  (ir_data[19:15]),
        .RA2  (ir_data[24:20]),
        .WA   (regfile_wa),
        .Wdata(regfile_wdata),
        .rf_we(regfile_we),
        .RD1  (rd1),
        .RD2  (rd2)
    );

    register_en U_A_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (operand_en),
        .data_in (rd1),
        .data_out(out_rd1)
    );

    register_en U_B_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (operand_en),
        .data_in (rd2),
        .data_out(out_rd2)
    );

    register_en U_IMM_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (operand_en),
        .data_in (imm_data),
        .data_out(out_imm_data)
    );

    alu U_ALU (
        .rd1        (out_rd1),
        .rd2        (alu_mux_out),
        .alu_control(alu_control),
        .alu_result (alu_result),
        .comp_result(comp_result)
    );

    register_en U_ALUOUT_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (alu_out_en),
        .data_in (alu_result),
        .data_out(out_alu_result)
    );

    register_en U_MDR_REG (
        .clk     (clk),
        .rst     (rst),
        .en      (mdr_en),
        .data_in (bus_rdata),
        .data_out(out_mdr_data)
    );

    imm_extender U_IMM_EXT (
        .instr_data(ir_data),
        .imm_data  (imm_data)
    );

    mux_2x1 U_2x1_MUX_ALU (
        .a      (out_rd2),
        .b      (out_imm_data),
        .sel    (alusrc),
        .mux_out(alu_mux_out)
    );

    mux_5x1 U_5x1_MUX (
        .a      (out_alu_result),
        .b      (out_mdr_data),
        .c      (out_imm_data),
        .d      (pc_rel_sum),
        .e      (old_pc4_sum),
        .sel    (rfwd_src),
        .mux_out(dmem_data_result)
    );

endmodule


module pc (
    input               clk,
    input               rst,
    input               pc_en,
    input        [31:0] address,
    output logic [31:0] instr_addr
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) instr_addr <= 32'd0;
        else if (pc_en) begin
            instr_addr <= address;
        end
    end

endmodule


module register_file (
    input               clk,
    input               rst,
    input        [ 4:0] RA1,
    input        [ 4:0] RA2,
    input        [ 4:0] WA,
    input        [31:0] Wdata,
    input               rf_we,
    output logic [31:0] RD1,
    output logic [31:0] RD2
);
    logic [31:0] reg_file[0:31];

    assign RD1 = (RA1 == 5'd0) ? 32'd0 : reg_file[RA1];
    assign RD2 = (RA2 == 5'd0) ? 32'd0 : reg_file[RA2];
    initial begin
        reg_file[27] = 32'h1000_0000;
        reg_file[28] = 32'h2000_4000;
        reg_file[29] = 32'h2000_4004;
        reg_file[30] = 32'h2000_4008;
        reg_file[31] = 32'h2000_400c;
    end
    always_ff @(posedge clk) begin
        if (!rst && rf_we && (WA != 5'd0)) begin
            reg_file[WA] <= Wdata;
        end
    end
endmodule


module alu (
    input        [31:0] rd1,
    input        [31:0] rd2,
    input        [ 3:0] alu_control,
    output logic [31:0] alu_result,
    output logic        comp_result
);

    always_comb begin
        alu_result = 32'd0;
        case (alu_control)
            `ADD:  alu_result = rd1 + rd2;
            `SUB:  alu_result = rd1 - rd2;
            `SLL:  alu_result = rd1 << rd2[4:0];
            `SLT:  alu_result = ($signed(rd1) < $signed(rd2)) ? 32'd1 : 32'd0;
            `SLTU: alu_result = (rd1 < rd2) ? 32'd1 : 32'd0;
            `XOR:  alu_result = rd1 ^ rd2;
            `SRL:  alu_result = rd1 >> rd2[4:0];
            `SRA:  alu_result = $signed(rd1) >>> rd2[4:0];
            `OR:   alu_result = rd1 | rd2;
            `AND:  alu_result = rd1 & rd2;
        endcase
    end

    always_comb begin
        comp_result = 1'd0;
        case (alu_control)
            `BEQ:  comp_result = (rd1 == rd2);
            `BNE:  comp_result = (rd1 != rd2);
            `BLT:  comp_result = ($signed(rd1) < $signed(rd2));
            `BGE:  comp_result = ($signed(rd1) >= $signed(rd2));
            `BLTU: comp_result = (rd1 < rd2);
            `BGEU: comp_result = (rd1 >= rd2);
        endcase
    end

endmodule


module imm_extender (
    input        [31:0] instr_data,
    output logic [31:0] imm_data
);

    always_comb begin
        imm_data = 32'h0;
        case (instr_data[6:0])
            `S_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]
                };
            end
            `I_TYPE, `IL_TYPE: begin
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `B_TYPE: begin
                imm_data = {
                    {19{instr_data[31]}},
                    instr_data[31],
                    instr_data[7],
                    instr_data[30:25],
                    instr_data[11:8],
                    1'b0
                };
            end
            `LUI_TYPE: begin
                imm_data = {instr_data[31:12], 12'b0};
            end
            `AUIPC_TYPE: begin
                imm_data = {instr_data[31:12], 12'b0};
            end
            `JAL_TYPE: begin
                imm_data = {
                    {11{instr_data[31]}},
                    instr_data[31],
                    instr_data[19:12],
                    instr_data[20],
                    instr_data[30:21],
                    1'b0
                };
            end
            `JALR_TYPE: begin
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
        endcase
    end

endmodule


module mux_2x1 (
    input  [31:0] a,
    input  [31:0] b,
    input         sel,
    output [31:0] mux_out
);

    assign mux_out = (sel) ? b : a;

endmodule

module mux_5x1 (
    input        [31:0] a,
    input        [31:0] b,
    input        [31:0] c,
    input        [31:0] d,
    input        [31:0] e,
    input        [ 2:0] sel,
    output logic [31:0] mux_out
);

    always_comb begin
        case (sel)
            3'b000:  mux_out = a;
            3'b001:  mux_out = b;
            3'b010:  mux_out = c;
            3'b011:  mux_out = d;
            3'b100:  mux_out = e;
            default: mux_out = 32'd0;
        endcase
    end
endmodule


module adder (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] s
);
    assign s = a + b;

endmodule


module register_en (
    input         clk,
    input         rst,
    input         en,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else if (en) begin
            register <= data_in;
        end
    end
    assign data_out = register;
endmodule

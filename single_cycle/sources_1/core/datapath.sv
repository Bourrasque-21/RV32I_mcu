`timescale 1ns / 1ps
`include "_define.vh"

module datapath (
    input               clk,
    input               rst,
    input        [ 3:0] alu_control,
    input        [31:0] instr_data,
    input               rf_we,
    input               alusrc,
    input        [ 2:0] rfwd_src,
    input               branch_c,
    input               jal_c,
    input               jalr_c,
    input        [31:0] drdata,
    output logic [31:0] daddr,
    output logic [31:0] d_wdata,
    output logic [31:0] instr_addr
);

    logic [31:0]
        rd1,
        rd2,
        alu_result,
        alu_mux_out,
        imm_data,
        dmem_data_result,
        btype_sum,
        pc4_sum,
        pc_final_addr,
        jalr_2_adder,
        pc_jump_addr;
    logic comp_result, b_branch, branch_x_jal;

    assign daddr = alu_result;
    assign d_wdata = rd2;
    assign b_branch = branch_c & comp_result;
    assign branch_x_jal = b_branch | jal_c | jalr_c;
    assign pc_jump_addr = (jalr_c) ? {btype_sum[31:1], 1'b0} : btype_sum;

    pc U_PC (
        .clk(clk),
        .rst(rst),
        .address(pc_final_addr),
        .instr_addr(instr_addr)
    );

    adder U_PC_4_ADDER (
        .a(instr_addr),
        .b(32'd4),
        .s(pc4_sum)
    );

    adder U_IMM_PC_ADDER (
        .a(imm_data),
        .b(jalr_2_adder),
        .s(btype_sum)
    );

    mux_2x1 PC_ADDR_SEL (
        .a      (pc4_sum),
        .b      (pc_jump_addr),
        .sel    (branch_x_jal),
        .mux_out(pc_final_addr)
    );

    mux_2x1 PC_JALR_MUX (
        .a      (instr_addr),
        .b      (rd1),
        .sel    (jalr_c),
        .mux_out(jalr_2_adder)
    );

    register_file U_REG_FILE (
        .clk  (clk),
        .rst  (rst),
        .RA1  (instr_data[19:15]),
        .RA2  (instr_data[24:20]),
        .WA   (instr_data[11:7]),
        .Wdata(dmem_data_result),
        .rf_we(rf_we),
        .RD1  (rd1),
        .RD2  (rd2)
    );

    alu U_ALU (
        .rd1        (rd1),
        .rd2        (alu_mux_out),
        .alu_control(alu_control),
        .alu_result (alu_result),
        .comp_result(comp_result)
    );

    imm_extender U_IMM_EXT (
        .instr_data(instr_data),
        .imm_data  (imm_data)
    );

    mux_2x1 U_2x1_MUX_ALU (
        .a      (rd2),
        .b      (imm_data),
        .sel    (alusrc),
        .mux_out(alu_mux_out)
    );

    mux_5x1 U_5x1_MUX (
        .a(alu_result),
        .b(drdata),
        .c(imm_data),
        .d(btype_sum),
        .e(pc4_sum),
        .sel(rfwd_src),
        .mux_out(dmem_data_result)
    );

endmodule


module pc (
    input               clk,
    input               rst,
    input        [31:0] address,
    output logic [31:0] instr_addr
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst) instr_addr <= 32'd0;
        else instr_addr <= address;
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

    //initial set
    initial begin
        reg_file[0] = 32'd0;  // x0 = 0
        reg_file[1] = 32'h12345678;  // x1 = -1

        for (int i = 2; i < 32; i++) begin
            reg_file[i] = i;  // x2 = 1, x3 = 2, x4 = 3, ...
        end
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

`timescale 1ns / 1ps

module rv32i_top (
    input clk,
    input rst
);

    logic [31:0] instr_addr, instr_data, d_wdata, drdata, daddr;
    logic [2:0] funct3_out;
    logic dwe, cpu_clk;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) cpu_clk <= 1'b0;
        else     cpu_clk <= ~cpu_clk;
    end

    instruction_mem U_INSTRUCTION_MEM (
        .instr_addr(instr_addr),
        .instr_data(instr_data)
    );
    rv32i_cpu U_RV32I (
        .clk(cpu_clk),
        .rst(rst),
        .instr_data(instr_data),
        .drdata(drdata),
        .instr_addr(instr_addr),
        .daddr(daddr),
        .d_wdata(d_wdata),
        .funct3_out(funct3_out),
        .dwe(dwe)
    );
    data_mem U_DATA_MEM (
        .clk(cpu_clk),
        .dwe(dwe),
        .daddr(daddr),
        .d_wdata(d_wdata),
        .drdata(drdata),
        .funct3_in(funct3_out)
    );

endmodule

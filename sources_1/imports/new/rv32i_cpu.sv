`timescale 1ns / 1ps
`include "_define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,
    input         interrupt_signal,
    output [31:0] instr_addr,
    output        bus_wreq,
    output        bus_rreq,
    output [31:0] bus_addr,
    output [31:0] bus_wdata,
    output [ 2:0] funct3_out,
    output        interrupt_clear
);

    logic pc_en, ir_en, oldpc_en, operand_en, alu_out_en, mdr_en;
    logic rf_we, alu_mux_sel, branch_c, jal_c, jalr_c, comp_result;
    logic save_return_addr, pc_sel_int;
    logic [31:0] ir_data_q;
    logic [ 2:0] w_rfwd_src;
    logic [ 3:0] alu_control;

    control_unit U_CONTROL_UNIT (
        .clk        (clk),
        .rst        (rst),
        .interrupt_signal(interrupt_signal),
        .ir_data    (ir_data_q),
        .comp_result(comp_result),
        .pc_en      (pc_en),
        .ir_en      (ir_en),
        .oldpc_en   (oldpc_en),
        .operand_en (operand_en),
        .alu_out_en (alu_out_en),
        .mdr_en     (mdr_en),
        .rf_we      (rf_we),
        .alusrc     (alu_mux_sel),
        .alu_control(alu_control),
        .rfwd_src   (w_rfwd_src),
        .funct3_out (funct3_out),
        .dwe        (bus_wreq),
        .dre        (bus_rreq),
        .branch_c   (branch_c),
        .jal_c      (jal_c),
        .jalr_c     (jalr_c),
        .ready      (bus_ready),
        .save_return_addr(save_return_addr),
        .pc_sel_int (pc_sel_int),
        .interrupt_clear(interrupt_clear)
    );

    datapath U_DATAPATH (
        .clk            (clk),
        .rst            (rst),
        .pc_en          (pc_en),
        .ir_en          (ir_en),
        .oldpc_en       (oldpc_en),
        .operand_en     (operand_en),
        .alu_out_en     (alu_out_en),
        .mdr_en         (mdr_en),
        .alu_control    (alu_control),
        .instr_data     (instr_data),
        .rf_we          (rf_we),
        .alusrc         (alu_mux_sel),
        .rfwd_src       (w_rfwd_src),
        .branch_c       (branch_c),
        .jal_c          (jal_c),
        .jalr_c         (jalr_c),
        .save_return_addr(save_return_addr),
        .pc_sel_int     (pc_sel_int),
        .bus_rdata      (bus_rdata),
        .bus_addr       (bus_addr),
        .bus_wdata      (bus_wdata),
        .instr_addr     (instr_addr),
        .ir_data        (ir_data_q),
        .out_comp_result(comp_result)
    );

endmodule


module control_unit (
    input               clk,
    input               rst,
    input        [31:0] ir_data,
    input               comp_result,
    input               ready,
    input               interrupt_signal,
    output logic        pc_en,
    output logic        ir_en,
    output logic        oldpc_en,
    output logic        operand_en,
    output logic        alu_out_en,
    output logic        mdr_en,
    output logic        branch_c,
    output logic        jal_c,
    output logic        jalr_c,
    output logic        rf_we,
    output logic        alusrc,
    output logic        dwe,
    output logic [ 2:0] funct3_out,
    output logic [ 2:0] rfwd_src,
    output logic [ 3:0] alu_control,
    output logic        dre,
    output logic        save_return_addr,
    output logic        pc_sel_int,
    output logic        interrupt_clear
);

    typedef enum logic [2:0] {
        IF,
        ID,
        EX,
        MEM,
        WB,
        INT
    } state_e;
    state_e c_state, n_state;

    logic [6:0] funct7;
    logic [2:0] funct3;
    logic [6:0] opcode;

    assign opcode = ir_data[6:0];
    assign funct3 = ir_data[14:12];
    assign funct7 = ir_data[31:25];

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IF;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        pc_en       = 1'b0;
        ir_en       = 1'b0;
        oldpc_en    = 1'b0;
        operand_en  = 1'b0;
        alu_out_en  = 1'b0;
        mdr_en      = 1'b0;
        rf_we       = 1'b0;
        alusrc      = 1'b0;
        alu_control = `ADD;
        dwe         = 1'b0;
        funct3_out  = 3'b0;
        rfwd_src    = 3'b0;
        branch_c    = 1'b0;
        jal_c       = 1'b0;
        jalr_c      = 1'b0;
        dre         = 1'b0;
        save_return_addr = 1'b0;
        pc_sel_int  = 1'b0;
        interrupt_clear = 1'b0;
        n_state     = c_state;
        case (c_state)
            IF: begin
                if (interrupt_signal) begin
                    n_state = INT;
                end else begin
                    pc_en    = 1'b1;
                    ir_en    = 1'b1;
                    oldpc_en = 1'b1;
                    n_state  = ID;
                end
            end
            ID: begin
                operand_en = 1'b1;
                n_state = EX;
            end
            EX: begin
                case (opcode)
                    `R_TYPE: begin
                        alu_out_en = 1'b1;
                        n_state = WB;
                        unique case ({
                            funct7, funct3
                        })
                            {7'b0000000, 3'b000} : alu_control = `ADD;
                            {7'b0100000, 3'b000} : alu_control = `SUB;
                            {7'b0000000, 3'b001} : alu_control = `SLL;
                            {7'b0000000, 3'b010} : alu_control = `SLT;
                            {7'b0000000, 3'b011} : alu_control = `SLTU;
                            {7'b0000000, 3'b100} : alu_control = `XOR;
                            {7'b0000000, 3'b101} : alu_control = `SRL;
                            {7'b0100000, 3'b101} : alu_control = `SRA;
                            {7'b0000000, 3'b110} : alu_control = `OR;
                            {7'b0000000, 3'b111} : alu_control = `AND;
                        endcase
                    end
                    `I_TYPE: begin
                        alu_out_en = 1'b1;
                        n_state    = WB;
                        alusrc     = 1'b1;
                        funct3_out = funct3;
                        if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                    end
                    `LUI_TYPE: begin
                        n_state = WB;
                    end
                    `AUIPC_TYPE: begin
                        n_state = WB;
                    end
                    `JAL_TYPE: begin
                        n_state = WB;
                        jal_c   = 1'b1;
                        pc_en   = 1'b1;
                    end
                    `JALR_TYPE: begin
                        n_state = WB;
                        jalr_c  = 1'b1;
                        pc_en   = 1'b1;
                    end
                    `S_TYPE: begin
                        alu_out_en = 1'b1;
                        n_state    = MEM;
                        alusrc     = 1'b1;
                        funct3_out = funct3;
                    end
                    `IL_TYPE: begin
                        alu_out_en = 1'b1;
                        n_state    = MEM;
                        alusrc     = 1'b1;
                        funct3_out = funct3;
                    end
                    `B_TYPE: begin
                        n_state     = IF;
                        funct3_out  = funct3;
                        branch_c    = 1'b1;
                        alu_control = {1'b0, funct3};
                        pc_en       = comp_result;
                    end
                    default: n_state = IF;
                endcase
            end
            MEM: begin
                case (opcode)
                    `IL_TYPE: begin
                        funct3_out = funct3;
                        dre        = 1'b1;
                        if (ready) begin
                            mdr_en  = 1'b1;
                            n_state = WB;
                        end
                    end
                    `S_TYPE: begin
                        funct3_out = funct3;
                        dwe        = 1'b1;
                        if (ready) begin
                            n_state = IF;
                        end
                    end
                    default: n_state = IF;
                endcase
            end
            WB: begin
                rf_we = 1'b1;
                case (opcode)
                    `IL_TYPE: begin
                        rfwd_src = 3'b001;
                    end
                    `LUI_TYPE: begin
                        rfwd_src = 3'b010;
                    end
                    `AUIPC_TYPE: begin
                        rfwd_src = 3'b011;
                    end
                    `JAL_TYPE, `JALR_TYPE: begin
                        rfwd_src = 3'b100;
                    end
                    default: rfwd_src = 3'b0;
                endcase
                n_state = IF;
            end
            INT: begin
                save_return_addr = 1'b1;
                pc_en            = 1'b1;
                pc_sel_int       = 1'b1;
                interrupt_clear = 1'b1;
                n_state          = IF;
            end
        endcase
    end
endmodule

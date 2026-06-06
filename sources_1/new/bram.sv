`timescale 1ns / 1ps
`include "_define.vh"

module data_dmem (
    input               clk,
    input               mem_read,
    input               mem_write,
    input        [ 2:0] i_funct3,
    input        [31:0] addr,
    input        [31:0] wdata,
    output logic        ready,
    output logic [31:0] rdata
);

    logic [31:0] w_wdata, w_drdata;
    bram U_BRAM (
        .clk     (clk),
        .addr    (addr),
        .wdata   (w_wdata),
        .write_en(mem_write),
        .rdata   (w_drdata)
    );

    assign ready = mem_read | mem_write;

    // S-type control for byte to word address
    always_comb begin
        w_wdata = w_drdata;
        case (i_funct3)
            `SW: w_wdata = wdata;
            `SH: begin
                if (addr[1] == 1'b1) w_wdata = {wdata[15:0], w_drdata[15:0]};
                else w_wdata = {w_drdata[31:16], wdata[15:0]};
            end
            `SB: begin
                case (addr[1:0])
                    2'b00: w_wdata = {w_drdata[31:8], wdata[7:0]};
                    2'b01: w_wdata = {w_drdata[31:16], wdata[7:0], w_drdata[7:0]};
                    2'b10: w_wdata = {w_drdata[31:24], wdata[7:0], w_drdata[15:0]};
                    2'b11: w_wdata = {wdata[7:0], w_drdata[23:0]};
                endcase
            end
        endcase
    end
    // IL-type control 
    always_comb begin
        rdata = w_drdata;
        case (i_funct3)
            `LW: rdata = w_drdata;
            `LH: begin
                if (addr[1] == 1'b1)
                    rdata[31:0] = {{16{w_drdata[31]}}, w_drdata[31:16]};
                else
                    rdata[31:0] = {{16{w_drdata[15]}}, w_drdata[15:0]};
            end
            `LB: begin
                case (addr[1:0])
                    2'b00: rdata[31:0] = {{24{w_drdata[7]}}, w_drdata[7:0]};
                    2'b01: rdata[31:0] = {{24{w_drdata[15]}}, w_drdata[15:8]};
                    2'b10: rdata[31:0] = {{24{w_drdata[23]}}, w_drdata[23:16]};
                    2'b11: rdata[31:0] = {{24{w_drdata[31]}}, w_drdata[31:24]};
                endcase
            end
            `LHU: begin
                if (addr[1] == 1'b1)
                    rdata[31:0] = {16'h0000, w_drdata[31:16]};
                else
                    rdata[31:0] = {16'h0000, w_drdata[15:0]};
            end
            `LBU: begin
                case (addr[1:0])
                    2'b00: rdata[31:0] = {{24{1'b0}}, w_drdata[7:0]};
                    2'b01: rdata[31:0] = {{24{1'b0}}, w_drdata[15:8]};
                    2'b10: rdata[31:0] = {{24{1'b0}}, w_drdata[23:16]};
                    2'b11: rdata[31:0] = {{24{1'b0}}, w_drdata[31:24]};
                endcase
            end
        endcase
    end

endmodule

module bram (
    input               clk,
    input        [31:0] addr,
    input        [31:0] wdata,
    input               write_en,
    output logic [31:0] rdata
);

    logic [31:0] bmem[0:1023];  // 1024 * 4byte : 4k

    initial begin
        // bmem[0] = 32'h12f4f678;
        // bmem[1] = 32'habcde123;
        // bmem[2] = 32'h12345678;
        for (int i = 0; i < 64; i++) begin
            bmem[i] = 32'h00000000;
        end
    end

    always_ff @(posedge clk) begin
        if (write_en) bmem[addr[11:2]] <= wdata;
    end

    assign rdata = bmem[addr[11:2]];

endmodule

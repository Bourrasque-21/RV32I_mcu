`timescale 1ns / 1ps
`include "_define.vh"

module data_mem (
    input               clk,
    input               dwe,
    input        [ 2:0] funct3_in,
    input        [31:0] daddr,
    input        [31:0] d_wdata,
    output logic [31:0] drdata
);
    // word address
    logic [31:0] dmem[0:511];
    always_ff @(posedge clk) begin
        if (dwe) begin
            case (funct3_in)
                `SB: begin
                    case (daddr[1:0])
                        2'b00: dmem[daddr[31:2]][7:0] <= d_wdata[7:0];
                        2'b01: dmem[daddr[31:2]][15:8] <= d_wdata[7:0];
                        2'b10: dmem[daddr[31:2]][23:16] <= d_wdata[7:0];
                        2'b11: dmem[daddr[31:2]][31:24] <= d_wdata[7:0];
                    endcase
                end

                `SH: begin
                    case (daddr[1])
                        1'b0: dmem[daddr[31:2]][15:0] <= d_wdata[15:0];
                        1'b1: dmem[daddr[31:2]][31:16] <= d_wdata[15:0];
                    endcase
                end

                `SW: begin
                    dmem[daddr[31:2]] <= d_wdata;
                end
            endcase
        end
    end
    always_comb begin
        drdata = 32'd0;
        if (dwe == 0) begin
            case (funct3_in)
                `LB: begin
                    case (daddr[1:0])
                        2'b00:
                        drdata = {
                            {24{dmem[daddr[31:2]][7]}}, dmem[daddr[31:2]][7:0]
                        };
                        2'b01:
                        drdata = {
                            {24{dmem[daddr[31:2]][15]}}, dmem[daddr[31:2]][15:8]
                        };
                        2'b10:
                        drdata = {
                            {24{dmem[daddr[31:2]][23]}},
                            dmem[daddr[31:2]][23:16]
                        };
                        2'b11:
                        drdata = {
                            {24{dmem[daddr[31:2]][31]}},
                            dmem[daddr[31:2]][31:24]
                        };
                    endcase
                end
                `LH: begin
                    case (daddr[1])
                        1'b0:
                        drdata = {
                            {16{dmem[daddr[31:2]][15]}}, dmem[daddr[31:2]][15:0]
                        };
                        1'b1:
                        drdata = {
                            {16{dmem[daddr[31:2]][31]}},
                            dmem[daddr[31:2]][31:16]
                        };
                    endcase
                end
                `LW: begin
                    drdata = dmem[daddr[31:2]];
                end
                `LBU: begin
                    case (daddr[1:0])
                        2'b00: drdata = {24'd0, {dmem[daddr[31:2]][7:0]}};
                        2'b01: drdata = {24'd0, {dmem[daddr[31:2]][15:8]}};
                        2'b10: drdata = {24'd0, {dmem[daddr[31:2]][23:16]}};
                        2'b11: drdata = {24'd0, {dmem[daddr[31:2]][31:24]}};
                    endcase
                end
                `LHU: begin
                    case (daddr[1])
                        1'b0: drdata = {16'd0, {dmem[daddr[31:2]][15:0]}};
                        1'b1: drdata = {16'd0, {dmem[daddr[31:2]][31:16]}};
                    endcase
                end
            endcase
        end
    end



    initial begin
        // dmem[0] = 32'h12f4f678;
        // dmem[1] = 32'habcde123;
        // dmem[2] = 32'h12345678;

        for (int i = 0; i < 32; i++) begin
            dmem[i] = 0;
        end
    end

endmodule

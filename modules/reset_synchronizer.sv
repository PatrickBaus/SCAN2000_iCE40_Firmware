`timescale 1ns / 1ps

/*
 * Asynchronous reset synchronizer
 *
 * The asynchronous reset has a major problem when the reset is
 * released close to a clock edge. Its release therefore needs
 * to be synced to clock.
 * See Asynchronous & Synchronous Reset Design Techniques - Part Deux
 * by Clifford E. Cummings for details.
*/

module async_reset_synchronizer (
    output logic rst_n,
    input clk, asyncrst_n
);
    logic [1:0] rst_n_r;

    always @(posedge clk or negedge asyncrst_n) begin
        if (!asyncrst_n) begin
            rst_n_r <= 2'b0;
        end
        else begin
            rst_n_r <= {rst_n_r[0], 1'b1};
        end
    end
    assign rst_n = rst_n_r[1];
endmodule

`default_nettype none
`timescale 1ns / 1ns

module count_ones #(parameter NBITS=8)(
    input [NBITS-1:0] number,
    output int result
);

integer i;

always @(number) begin
    result = 0;
    for(i = 0; i < NBITS; i = i + 1) begin
        result +=number[i];
    end
end

endmodule

`default_nettype none
`timescale 1ns / 1ns

module cdc_shift_register #(parameter NBITS=24)(
    input  wire logic CLK_SYS,
    input  wire logic SCK,
    input  wire logic SDI,
    input  wire logic LATCH,
    output      logic [NBITS-1:0] OUTPUT_BUFFER_r,
    output      logic DATA_READY,
    input  wire logic RESET
);

    logic [NBITS-1:0] INPUT_BUFFER_r;

    // We will transfer all external signals coming from the DMM to the internal clock domain.
    // This makes working with the signals a lot easier.

    // ******
    // Transfer the serial clock signal to the core clock domain.

    logic [2:0] SCK_r;      // Rising edge detector needs 3 bits
    wire SCK_rising_edge = SCK_r[1] && ~SCK_r[2];
    //wire SCK_falling_edge = ~SCK_r[1] && SCK_r[2];    // for educational purposes
    always_ff @(posedge CLK_SYS or negedge RESET) begin
        if (!RESET) begin
            SCK_r <= 3'd0;
        end
        else begin
            SCK_r <= {SCK_r[1:0], SCK};
        end
    end

    // ******
    // Transfer the serial data input (SDI) to the core clock domain

    logic [1:0] SDI_r;
    wire SDI_data = SDI_r[1];
    always_ff @(posedge CLK_SYS or negedge RESET) begin
        if (!RESET) begin
            SDI_r <= 2'd0;
        end
        else begin
            SDI_r <= {SDI_r[0], SDI};
        end
    end

    // ******
    // Transfer the latch signal to the core clock domain

    logic [2:0] LATCH_r;      // Rising edge detector needs 3 bits
    wire LATCH_rising_edge = LATCH_r[1] && ~LATCH_r[2];
    //wire LATCH_falling_edge = ~LATCH_r[1] && LATCH_r[2];    // for educational purposes
    always_ff @(posedge CLK_SYS or negedge RESET) begin
        if (!RESET) begin
            LATCH_r <= 3'd0;
        end
        else begin
            LATCH_r <= {LATCH_r[1:0], LATCH};
        end
    end

    // ******
    // Read the data from the SDI and put it into the register. Toggle the DATA_READY output on
    // a rising edge of the LATCH input

    always_ff @(posedge CLK_SYS or negedge RESET) begin
        if (!RESET) begin
            INPUT_BUFFER_r <= {NBITS{1'b0}};
            OUTPUT_BUFFER_r <= {NBITS{1'b0}};
            DATA_READY <= 1'b0;
        end
        else if (SCK_rising_edge) begin
            INPUT_BUFFER_r <= {INPUT_BUFFER_r[NBITS-2:0], SDI_data};
            DATA_READY <= 1'b0;
        end
        else if (LATCH_rising_edge) begin
            OUTPUT_BUFFER_r <= INPUT_BUFFER_r;
            DATA_READY <= 1'b1;
        end
        else begin
            INPUT_BUFFER_r <= INPUT_BUFFER_r;
            DATA_READY <= 1'b0;
        end
    end

endmodule

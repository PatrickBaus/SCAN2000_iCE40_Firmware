`include "scan2000.sv"
// `timescale <time_unit>/<time_precision>
`timescale 1ns/1ns

module scan200_tb;

bit clockEnabled = 0;
bit CH20_mode_enable;
logic CLK_SYS;
logic CLK_DMM, DATA_DMM_r, STROBE_DMM;
wire logic DATA_DMM;
logic CH1, CH2, CH3, CH4, CH5, CH6, CH7, CH8, CH9, CH10,
        CH11, CH12, CH13, CH14, CH15, CH16, CH17, CH18, CH19, CH20,
        Bus2_sense_enable, Bus2_input_enable;

// 16 MHz FPGA clock
localparam integer fpga_clk_period = 62.5; // ns

// 2 MHz DMM clock
localparam integer dmm_clk_period = 500; // ns

wire logic [21:0] RELAY_STATE;
assign RELAY_STATE = {Bus2_sense_enable, Bus2_input_enable, CH20, CH19, CH18, CH17, CH16, CH15, CH14, CH13, CH12, CH11,
        CH10, CH9, CH8, CH7, CH6, CH5, CH4, CH3, CH2, CH1};
assign DATA_DMM = DATA_DMM_r && clockEnabled;

scan2000 UUT(.*);

// Emulate the FPGA clock, see fpga_clk_period above for details
always begin
    #(fpga_clk_period/2 * 1ns) CLK_SYS = ~CLK_SYS;
end

logic [47:0] data_out;
logic [21:0] expected_states[$];
int num_recv;

task automatic sendCommand(logic [47:0] command, int cycles, logic [21:0] expected_state);
    data_out = command;
    expected_states.push_back(expected_state);
    // Emulate the 2 MHz DMM clock
    #100 repeat (cycles*2) begin
        #(dmm_clk_period/2 * 1ns) CLK_DMM = ~CLK_DMM;
        clockEnabled = 1;  // Enable the clock on the first tick
    end
    #(dmm_clk_period/2 * 1ns) clockEnabled = 0;
    #500 STROBE_DMM = 1;
    #500 STROBE_DMM = 0;
endtask

task automatic injectTraffic(logic [47:0] command, int cycles);
    data_out = command;
    // Emulate the 2 MHz DMM clock
    #100 repeat (cycles*2) begin
        #(dmm_clk_period/2 * 1ns) CLK_DMM = ~CLK_DMM;
        clockEnabled = 1;  // Enable the clock on the first tick
    end
    clockEnabled = 0;
endtask

task automatic sendK2000Command(input logic [23:0] command, input logic [21:0] expected_state);
    sendCommand(24'hAA45B5, 24, {2'b00, 10'b0, 10'b0});
    #100;
    sendCommand(24'h000480, 24, {2'b00, 10'b0, 10'b0});
    #100;
    sendCommand(command, 24, expected_state);
    #100;
    sendCommand(24'h000480, 24, expected_state);
endtask

task automatic test10CH();
    // K2000 Startup
    sendCommand(24'hAA55B5, 24, {2'b00, 10'b0, 10'b0});  // Set bank 1 to CH1, others are off, bank 2 is disconnected
    #100;
    sendCommand(24'h000480, 24, {2'b00, 10'b0, 10'b0});

    // DMM6500 Startup. Note: The FPGA ignores the command to connect the 4W port without when nothing is connected to bank 2
    sendCommand(24'hAA4DB5, 24, {2'b00, 10'b0, 10'b0});  // Set bank 1 to CH1, others are off, bank 2 is disconnected
    #100;
    sendCommand(24'h000480, 24, {2'b00, 10'b0, 10'b0});
    #100;
    sendCommand(24'h001480, 24, {2'b00, 10'b0, 10'b0});  // Disable 4W mode
    #100;
    sendCommand(24'h000480, 24, {2'b00, 10'b0, 10'b0});

    // Close CH1 (K2000 style)
    sendK2000Command(24'h011480, {2'b00, 10'b0, 10'b1});
    // Open CH1 -> Close CH2 (DMM6500 style)
    sendCommand(24'h020480, 24, {2'b00, 10'b0, 10'b0});
    #100;
    sendCommand(24'h000480, 24, {2'b00, 10'b0, 10'b0});
    #100;
    sendCommand(24'h040480, 24, {2'b00, 10'b0, 10'b10});
    #100;
    sendCommand(24'h000480, 24, {2'b00, 10'b0, 10'b10});

    // Use CH1 as input and CH11 as the 4W terminal
    sendK2000Command(24'h012C80, {2'b10, 10'b1, 10'b1});

    // Use CH1 in 2W mode (as above)
    sendK2000Command(24'h011480, {2'b00, 10'b0, 10'b1});

    // Use CH2 as input and CH12 as the 4W terminal
    sendK2000Command(24'h048C80, {2'b10, 10'b10, 10'b10});

    // Close CH10, needs bank 2 connected to the sense port
    sendK2000Command(24'h0014C0, {2'b01, 10'b10000, 10'b0});
endtask

task automatic test10CHK2002();
    /* This function injects other device traffic in data stream
       like the K2002 does.*/

    // Startup
    sendCommand(24'hAA55B5, 24, {2'b00, 10'b0, 10'b0});  // Set bank 1 to CH1, others are off, bank 2 is disconnected
    #100;

    // Close CH1
    sendCommand(24'h011480, 24, {2'b00, 10'b0, 10'b1});
    #1000;

    injectTraffic(24'b0, 1);  // Inject a low rogue bit, this should not change anything
    #500
    injectTraffic(24'h800000, 1);  // Inject a low rogue bit, this should not change anything
    #1000

    // Open CH1
    sendCommand(24'h001480, 24, {2'b00, 10'b0, 10'b1});  // Disable 4W
    sendCommand(24'h020480, 24, {2'b00, 10'b0, 10'b0});  // Turn off CH1

endtask

task automatic send20ChCommand(input logic [47:0] command, input logic [21:0] expected_state);
    sendCommand(command, 48, expected_state);
    #100;
    sendCommand(48'h000000000000, 48, expected_state);  // This command is sent by the DMM because the 2000-SCAN card has latching relays and the coils need to be turned off again
endtask

task automatic test20CH();
    /*
    The DMM6500 and the K2000 do this slightly different. The K2000 will always open
    all channels before closing another one. It does this by opening bank 1 first,
    sending 0x055555000000, then bank 2, sending 0x555555. The DMM6500 only sends
    the diff, only closing the previous and opening the new relay.
    */
    // Open all channels and set 4W mode to input
    send20ChCommand(48'h015555555555, {2'b00, 10'b0, 10'b0});
    // Use CH1
    send20ChCommand(48'h000000200000, {2'b00, 10'b0, 10'b1});
    // Use CH2 coming from CH1
    send20ChCommand(48'h000000100000, {2'b00, 10'b0, 10'b0});
    send20ChCommand(48'h000000800000, {2'b00, 10'b0, 10'b10});

    // Reset the Relays
    send20ChCommand(48'h015555555555, {2'b00, 10'b0, 10'b0});
    // Use CH1 as input and CH11 as the 4W terminal
    send20ChCommand(48'h020000200002, {2'b10, 10'b1, 10'b1});
    // Use CH2 as input and CH12 as the 4W terminal coming from default
    send20ChCommand(48'h015555555555, {2'b00, 10'b0, 10'b0});  // reset
    send20ChCommand(48'h020000800008, {2'b10, 10'b10, 10'b10});
    // Use CH10 as input and CH20 as the 4W terminal coming from default
    send20ChCommand(48'h015555555555, {2'b00, 10'b0, 10'b0});  // reset
    send20ChCommand(48'h028000080000, {2'b10, 10'b1000000000, 10'b1000000000});
    // Use CH10 as input and CH20 as the 4W terminal coming from CH2 4W
    send20ChCommand(48'h015555555555, {2'b00, 10'b0, 10'b0});  // reset
    send20ChCommand(48'h020000800008, {2'b10, 10'b10, 10'b10});  // set CH2
    send20ChCommand(48'h000000400004, {2'b00, 10'b0, 10'b0});  // reset CH2, note: The FPGA automatically disconnects the 4W relay as well, hence the first 2 bits of the final state are set to 2'b00
    send20ChCommand(48'h008000080000, {2'b10, 10'b1000000000, 10'b1000000000});  // set CH10, note: It is not required to enable the 4W relay. This is remembered form the previous commands

    // Use CH10 coming from CH10 4W
    send20ChCommand(48'h010000040000, {2'b00, 10'b0, 10'b1000000000});
endtask

task automatic testRelayState();
    wait(STROBE_DMM == 1);
    #1000;
    assert (RELAY_STATE == expected_states[num_recv])
    else begin
        $error("%m invalid relay state. Received: 0b%22b Expected: 0b%22b.", RELAY_STATE, expected_states[num_recv]);
        $fflush();
        $stop;
    end
    num_recv = num_recv + 1;
endtask

always begin
    testRelayState();
end

initial begin
    CLK_SYS = 0;
    CLK_DMM = 0;
    STROBE_DMM = 0;
    DATA_DMM_r = 0;
    UUT.RST_n = 0;
    CH20_mode_enable = 0;  // Set the FPGA to 10 channel mode (24 data bits)
    #100 UUT.RST_n = 1;
    test10CH();
    test10CHK2002();  // Add a test with some other devices on the bus

    #5000 CH20_mode_enable = 1;  // Set the FPGA to 20 channel mode (48 data bits)
    UUT.RST_n = 0;
    #100 UUT.RST_n = 1;
    #1000;
    test20CH();
    #5000;
    $finish;
end

//logic [47:0] data_out = 24'h011480;
always @(posedge CLK_DMM) begin
    if (CH20_mode_enable == 1) begin
        DATA_DMM_r <= clockEnabled && data_out[47];
        data_out <= {data_out[46:0], 1'b0};
    end
    else begin
        DATA_DMM_r <= clockEnabled && data_out[23];
        data_out <= {data_out[22:0], 1'b0};
    end

end

/*
// A clock generator that allows to inject glitches into the ADC clock
wire logic adc_test_clk;
logic adc_glitch_clk;
assign adc_test_clk = CLK_ADC_MASTER_OUT | adc_glitch_clk;

initial begin
    CLK_SYS = 0;
    SDOA = 0;
    DRL = 0;
    RESET = 0;
    SYSTEM_UP = 0;
    adc_glitch_clk = 0;
    #10 RESET = 1;
    #10 SYSTEM_UP = 1;
end

initial begin
    #100 adc_glitch_clk = 1;        // insert random ADC clock glitch here
    #20 adc_glitch_clk = 0;
end

logic [15:0] conversion_clk_counter;
localparam down_sampling_factor = 16'b11;
localparam SDOA_data = 32'hAAAAAAAA;
//localparam SDOA_data = 32'b1;
logic [31:0] data_out = SDOA_data;
always @(posedge adc_test_clk or posedge SYNC_OUT) begin
    if (SYNC_OUT) begin
        conversion_clk_counter <= 16'd0;
    end
    else begin
        conversion_clk_counter <= (conversion_clk_counter + 16'd1) & down_sampling_factor;
        if (conversion_clk_counter == down_sampling_factor - 1) begin
            #18 DRL <= 1;
            #652 DRL <= 0;
            SDOA <= 1'bx;  // t_DSDOADRLL = 5 ns
            #5 SDOA <= SDOA_data[31];
            data_out <= SDOA_data;
        end
    end
end

always @(posedge CLK_ADC_SCKA_OUT) begin
    data_out <= {data_out[30:0], data_out[0]};
    #1 SDOA <= 1'bx;                // t_HSDOA = 1 ns
    #7.5 SDOA <= data_out[31];      // t_DSDOA = 8.5 ns
end

*/
initial begin
    $dumpfile ("scan200_tb.vcd");
    $dumpvars (0,scan200_tb);
end
endmodule

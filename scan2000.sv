`include "modules/reset_synchronizer.sv"
`include "modules/shift_register.sv"
`include "modules/count_ones.sv"
module scan2000(
    input  wire bit CH20_mode_enable,
    input  wire logic CLK_SYS,
    input  wire logic CLK_DMM, DATA_DMM, STROBE_DMM,
    output wire logic CH1, CH2, CH3, CH4, CH5, CH6, CH7, CH8, CH9, CH10,
        CH11, CH12, CH13, CH14, CH15, CH16, CH17, CH18, CH19, CH20,
        Bus2_sense_enable, Bus2_input_enable
    );

    wire logic [19:0] CHANNELS;
    assign {CH20, CH19, CH18, CH17, CH16, CH15, CH14, CH13, CH12, CH11,
        CH10, CH9, CH8, CH7, CH6, CH5, CH4, CH3, CH2, CH1} = CHANNELS;

    // ******
    // Reset generation. The async reset is transferred to the local clock domain and then
    // distributed asynchronously to all flip flops.

    // Currently the CRESET_B pin of the iCE40 is used to reset the whole device and reconfigure it.
    // If in future a reset pin is required, assign RST_n to this pin.
    logic RST_n = 1;    // async reset input. Warning, it needs to be synced to the clock to avoid being de-asserted close to a clock edge
    logic RESET_n;      // synced reset signal.
    async_reset_synchronizer reset_synchronizer(
        .clk(CLK_SYS),
        .asyncrst_n(RST_n),
        .rst_n(RESET_n)
    );

    // ******
    // Mode selection switch
    // Read the mode selection input once after boot, then keep that state until reset
    bit [1:0] mode_select_rdy = 2'b00;
    logic [1:0] MODE_20CH_r = 2'b00;
    bit MODE_20CH;
    assign MODE_20CH = MODE_20CH_r[1];
    always_ff @(posedge CLK_SYS or negedge RESET_n) begin
        if (!RESET_n) begin
            MODE_20CH_r <= 2'b00;
            mode_select_rdy <= 2'b00;
        end
        else begin
            // If the 'mode_select_rdy' flag is not set, read the CH20_mode_enable,
            // otherwise latch the 'MODE_20CH_r' register
            if (!mode_select_rdy[1]) begin
                mode_select_rdy <= {mode_select_rdy[0], 1'b1};
                MODE_20CH_r <= {MODE_20CH_r[0], CH20_mode_enable};
            end
            else begin
                mode_select_rdy <= mode_select_rdy;
                MODE_20CH_r <= MODE_20CH_r;
            end
        end
    end

    // ******
    // 48 bit input shift register with latch
    logic [47:0] DATA_BUFFER_r;
    logic DATA_READY;       // Signals that the data in the buffer is ready to be read

    cdc_shift_register #(.NBITS(48)) SHIFT_REGISTER(
        .CLK_SYS(CLK_SYS),
        .SCK(CLK_DMM),
        .SDI(DATA_DMM),
        .LATCH(STROBE_DMM),
        .OUTPUT_BUFFER_r(DATA_BUFFER_r),
        .DATA_READY(DATA_READY),
        .RESET(RESET_n)
    );

    // ******
    // Input state machine. The opto relays need to be driven permanentely unlike the
    // latching relays used in the original design
    logic [21:0] NEW_STATE_r = 22'b0;
    logic [21:0] RELAY_STATE_r = 22'b0;
    assign Bus2_sense_enable = RELAY_STATE_r[21] && (|RELAY_STATE_r[19:10]);    // Disconnect bus 2 if there are no channels connected to it
    assign Bus2_input_enable = RELAY_STATE_r[20] && (|RELAY_STATE_r[19:10]);    // Disconnect bus 2 if there are no channels connected to it
    assign CHANNELS = RELAY_STATE_r[19:0];
    int number_of_bus1_channels_enabled;
    int number_of_bus2_channels_enabled;

    // Count the number of channels that are enabled in each bank
    count_ones #(.NBITS(10)) COUNT_BUS1(
        .number(NEW_STATE_r[9:0]),
        .result(number_of_bus1_channels_enabled)
    );
    count_ones #(.NBITS(10)) COUNT_BUS2(
        .number({NEW_STATE_r[19:10]}),
        .result(number_of_bus2_channels_enabled)
    );

    bit has_fault;
    assign has_fault =
        (NEW_STATE_r[20] && NEW_STATE_r[21])    // Both sense and input relays are enabled
        || (NEW_STATE_r[20] && (number_of_bus1_channels_enabled + number_of_bus2_channels_enabled > 1))   // both buses are connected and more than 1 channel is enabled
        || (NEW_STATE_r[21] && (number_of_bus1_channels_enabled > 1) || (number_of_bus2_channels_enabled > 1))
    ;

    always_ff @(posedge CLK_SYS or negedge RESET_n) begin
        if (!RESET_n) begin
            RELAY_STATE_r <= 22'b0;
        end
        else begin
            if (has_fault) begin
                RELAY_STATE_r <= RELAY_STATE_r;
            end
            else begin
                RELAY_STATE_r <= NEW_STATE_r;
            end
        end
    end

    // ******
    // Input decoder
    // In case of the 10 CH card the relay state is encoded as
    // Channel Off Sequence = {17, 19, 21, 23, 8, 14, 0, 2, 4, 5, 12};      // CH1..CH10, 4W
    // Channel On Sequence = {16, 18, 20, 22, 9, 13, 15, 1, 3, 6, 11};      // CH1..CH10, 4W
    // In case of the 20 CH card, the commands are more logical. All
    // Odd bits turn the relays on, even bits turn them off, the reason is
    // the hardware. They used a 2 coil (set and reset coil) latching relay.
    // The odd bit is wired to the set coil and the even bits are wired to the
    // reset coil.

    always_ff @(posedge CLK_SYS or negedge RESET_n) begin
        if (!RESET_n) begin
            NEW_STATE_r <= 22'b0;
        end
        else begin
            if (DATA_READY) begin
                if (MODE_20CH) begin
                    // 20 channel relay card
                    NEW_STATE_r <= {
                        // 4W Mode, Keithley uses a single relay to switch between bank 2 to 4W or bank 2 to input (default)
                        // Setting CH21 activates 4W mode, and unsetting changes it back to input mode
                        (RELAY_STATE_r[21] || DATA_BUFFER_r[2*20+1]) && !DATA_BUFFER_r[2*20],   // Bank 2 to sense
                        (RELAY_STATE_r[20] || DATA_BUFFER_r[2*20]) && !DATA_BUFFER_r[2*20+1],   // Bank 2 to input
                        // Bank 2
                        (RELAY_STATE_r[19] || DATA_BUFFER_r[2*9+1]) && !DATA_BUFFER_r[2*9],
                        (RELAY_STATE_r[18] || DATA_BUFFER_r[2*8+1]) && !DATA_BUFFER_r[2*8],
                        (RELAY_STATE_r[17] || DATA_BUFFER_r[2*7+1]) && !DATA_BUFFER_r[2*7],
                        (RELAY_STATE_r[16] || DATA_BUFFER_r[2*6+1]) && !DATA_BUFFER_r[2*6],
                        (RELAY_STATE_r[15] || DATA_BUFFER_r[2*5+1]) && !DATA_BUFFER_r[2*5],
                        (RELAY_STATE_r[14] || DATA_BUFFER_r[2*4+1]) && !DATA_BUFFER_r[2*4],
                        (RELAY_STATE_r[13] || DATA_BUFFER_r[2*3+1]) && !DATA_BUFFER_r[2*3],
                        (RELAY_STATE_r[12] || DATA_BUFFER_r[2*2+1]) && !DATA_BUFFER_r[2*2],
                        (RELAY_STATE_r[11] || DATA_BUFFER_r[2*1+1]) && !DATA_BUFFER_r[2*1],
                        (RELAY_STATE_r[10] || DATA_BUFFER_r[2*0+1]) && !DATA_BUFFER_r[2*0],
                        // Bank 1
                        (RELAY_STATE_r[9] || DATA_BUFFER_r[2*19+1]) && !DATA_BUFFER_r[2*19],
                        (RELAY_STATE_r[8] || DATA_BUFFER_r[2*18+1]) && !DATA_BUFFER_r[2*18],
                        (RELAY_STATE_r[7] || DATA_BUFFER_r[2*17+1]) && !DATA_BUFFER_r[2*17],
                        (RELAY_STATE_r[6] || DATA_BUFFER_r[2*16+1]) && !DATA_BUFFER_r[2*16],
                        (RELAY_STATE_r[5] || DATA_BUFFER_r[2*15+1]) && !DATA_BUFFER_r[2*15],
                        (RELAY_STATE_r[4] || DATA_BUFFER_r[2*14+1]) && !DATA_BUFFER_r[2*14],
                        (RELAY_STATE_r[3] || DATA_BUFFER_r[2*13+1]) && !DATA_BUFFER_r[2*13],
                        (RELAY_STATE_r[2] || DATA_BUFFER_r[2*12+1]) && !DATA_BUFFER_r[2*12],
                        (RELAY_STATE_r[1] || DATA_BUFFER_r[2*11+1]) && !DATA_BUFFER_r[2*11],
                        (RELAY_STATE_r[0] || DATA_BUFFER_r[2*10+1]) && !DATA_BUFFER_r[2*10]
                    };
                end
                else begin
                    // 10 channel relay card
                    NEW_STATE_r <= {
                        // 4W Mode
                        (RELAY_STATE_r[21] || DATA_BUFFER_r[11]) && !DATA_BUFFER_r[12], // Bank 2 to sense
                        (RELAY_STATE_r[20] || DATA_BUFFER_r[12]) && !DATA_BUFFER_r[11], // Bank 2 to input
                        // Bank 2
                        5'b0,   // CH16-CH20 on the card are not used
                        (RELAY_STATE_r[14] || DATA_BUFFER_r[6]) && !DATA_BUFFER_r[5],
                        (RELAY_STATE_r[13] || DATA_BUFFER_r[3]) && !DATA_BUFFER_r[4],
                        (RELAY_STATE_r[12] || DATA_BUFFER_r[1]) && !DATA_BUFFER_r[2],
                        (RELAY_STATE_r[11] || DATA_BUFFER_r[15]) && !DATA_BUFFER_r[0],
                        (RELAY_STATE_r[10] || DATA_BUFFER_r[13]) && !DATA_BUFFER_r[14],
                        // Bank 1
                        5'b0,   // CH6-CH10 on the card are not used
                        (RELAY_STATE_r[4] || DATA_BUFFER_r[9]) && !DATA_BUFFER_r[8],
                        (RELAY_STATE_r[3] || DATA_BUFFER_r[22]) && !DATA_BUFFER_r[23],
                        (RELAY_STATE_r[2] || DATA_BUFFER_r[20]) && !DATA_BUFFER_r[21],
                        (RELAY_STATE_r[1] || DATA_BUFFER_r[18]) && !DATA_BUFFER_r[19],
                        (RELAY_STATE_r[0] || DATA_BUFFER_r[16]) && !DATA_BUFFER_r[17]
                    };
                end
            end
            else begin
                NEW_STATE_r <= NEW_STATE_r;
            end
        end
    end
endmodule

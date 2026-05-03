// Top-level module: Tasks 1 + 2 + 3 combined.
//
// SW9 = 0 : Audio pass-through (Task 1)
// SW9 = 1 : Tone from ROM     (Task 2)
// SW8 = 0 : Unfiltered output
// SW8 = 1 : FIR averaging filter applied (Task 3)
//
// Before compiling:
//   1. Generate your MIF with the Python script.
//   2. Create the ROM IP in Quartus (named "tone_rom", 24-bit, M10K, Single clock).
//   3. Update NUM_WORDS to match the DEPTH in your MIF file.
//   4. Update FIR_N / FIR_LOG2_N together if experimenting with filter size.

module part1 (CLOCK_50, CLOCK2_50, KEY, SW, FPGA_I2C_SCLK, FPGA_I2C_SDAT,
              AUD_XCK, AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK, AUD_ADCDAT, AUD_DACDAT);

    input        CLOCK_50, CLOCK2_50;
    input  [0:0] KEY;
    input  [9:0] SW;
    output       FPGA_I2C_SCLK;
    inout        FPGA_I2C_SDAT;
    output       AUD_XCK;
    input        AUD_DACLRCK, AUD_ADCLRCK, AUD_BCLK;
    input        AUD_ADCDAT;
    output       AUD_DACDAT;

    wire reset = ~KEY[0];

    // -------------------------------------------------------------------------
    // CODEC interface — wires match the audio_codec module port order exactly
    // -------------------------------------------------------------------------
    wire        read_ready, write_ready;
    wire [23:0] readdata_left, readdata_right;

    // read, write, and writedata are driven combinationally to avoid any
    // register-vs-wire timing mismatch between write and writedata
    wire        read, write;
    wire [23:0] writedata_left, writedata_right;

    // -------------------------------------------------------------------------
    // Task 2: ROM tone playback
    // !! Set NUM_WORDS to the DEPTH value at the top of your MIF file !!
    // -------------------------------------------------------------------------
    localparam NUM_WORDS = 1024;

    wire        t2_write;
    wire [23:0] t2_left, t2_right;

    task2 #(.NUM_WORDS(NUM_WORDS)) u_task2 (
        .clk             (CLOCK_50),
        .reset           (reset),
        .write_ready     (write_ready),
        .write           (t2_write),
        .writedata_left  (t2_left),
        .writedata_right (t2_right)
    );

    // -------------------------------------------------------------------------
    // Task 3: FIR filter — one instance per audio channel
    // !! Change FIR_N and FIR_LOG2_N together — N must be a power of 2 !!
    // -------------------------------------------------------------------------
    localparam FIR_N      = 8;
    localparam FIR_LOG2_N = 3;

    // Select the raw unfiltered source based on SW9
    wire signed [23:0] raw_left  = SW[9] ? t2_left  : readdata_left;
    wire signed [23:0] raw_right = SW[9] ? t2_right : readdata_right;

    // FIR update condition:
    //   SW9=0 (Task 1): update on read_ready & write_ready (same as pass-through)
    //   SW9=1 (Task 2): update on write_ready only (no mic read, ROM drives timing)
    wire fir_update = SW[9] ? write_ready : (read_ready & write_ready);

    wire signed [23:0] filt_left, filt_right;

    task3 #(.N(FIR_N), .LOG2_N(FIR_LOG2_N)) u_fir_left (
        .clk        (CLOCK_50),
        .reset      (reset),
        .update     (fir_update),
        .sample_in  (raw_left),
        .sample_out (filt_left)
    );

    task3 #(.N(FIR_N), .LOG2_N(FIR_LOG2_N)) u_fir_right (
        .clk        (CLOCK_50),
        .reset      (reset),
        .update     (fir_update),
        .sample_in  (raw_right),
        .sample_out (filt_right)
    );

    // -------------------------------------------------------------------------
    // SW8 mux: filtered vs unfiltered
    // -------------------------------------------------------------------------
    wire [23:0] out_left  = SW[8] ? filt_left  : raw_left;
    wire [23:0] out_right = SW[8] ? filt_right : raw_right;

    // -------------------------------------------------------------------------
    // Drive CODEC control signals — all combinational so write and writedata
    // are always in sync (no register delay between them)
    //
    // SW9=0 (Task 1): read & write both fire when read_ready & write_ready
    // SW9=1 (Task 2): task2 drives write timing; read stays low (no mic needed)
    // -------------------------------------------------------------------------
    assign read           = (~SW[9]) & read_ready & write_ready;
    assign write          = SW[9] ? t2_write : (read_ready & write_ready);
    assign writedata_left  = out_left;
    assign writedata_right = out_right;

    // -------------------------------------------------------------------------
    // Infrastructure
    // -------------------------------------------------------------------------
    clock_generator my_clock_gen (
        CLOCK2_50,
        reset,
        AUD_XCK
    );

    audio_and_video_config cfg (
        CLOCK_50,
        reset,
        FPGA_I2C_SDAT,
        FPGA_I2C_SCLK
    );

    audio_codec codec (
        CLOCK_50,
        reset,
        read,   write,
        writedata_left, writedata_right,
        AUD_ADCDAT,
        AUD_BCLK,
        AUD_ADCLRCK,
        AUD_DACLRCK,
        read_ready, write_ready,
        readdata_left, readdata_right,
        AUD_DACDAT
    );

endmodule

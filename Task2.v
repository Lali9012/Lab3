// Task 2: Play a tone stored in ROM to the audio CODEC.
//
// HOW TO USE:
//   1. Generate your MIF file with the provided Python script.
//   2. Quartus: Tools -> IP Catalog -> Library -> Basic Functions ->
//      On Chip Memory -> ROM: 1-PORT
//   3. Name it "tone_rom", 24-bit word width, word count from your MIF,
//      M10K block type, Single clock.
//   4. Set initial contents to your MIF file.
//   5. Add the generated .v and .qip to your project.
//
// Set NUM_WORDS to match the number of words in your MIF file.

module task2 #(parameter NUM_WORDS = 1024) (
    input             clk,
    input             reset,
    input             write_ready,
    output reg        write,
    output     [23:0] writedata_left,
    output     [23:0] writedata_right
);
    localparam ADDR_BITS = $clog2(NUM_WORDS);

    reg [ADDR_BITS-1:0] addr;
    wire [23:0] rom_data;

    // Quartus-generated ROM — you must create this via IP Catalog
    tone_rom rom_inst (
        .address (addr),
        .clock   (clk),
        .q       (rom_data)
    );

    // Same sample on both channels
    assign writedata_left  = rom_data;
    assign writedata_right = rom_data;

    // Advance ROM address exactly once per write, looping at end
    always @(posedge clk) begin
        if (reset) begin
            addr  <= 0;
            write <= 1'b0;
        end else if (write_ready) begin
            write <= 1'b1;
            addr  <= (addr == NUM_WORDS - 1) ? 0 : addr + 1;
        end else begin
            write <= 1'b0;
        end
    end

endmodule

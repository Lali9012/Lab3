`timescale 1ns/1ps
module task3_tb;
    reg clk, reset, update;
    reg signed [23:0] sample_in;
    wire signed [23:0] sample_out;

    // Instantiate with N=8
    task3 #(.N(8), .LOG2_N(3)) dut (
        .clk(clk), .reset(reset), .update(update),
        .sample_in(sample_in), .sample_out(sample_out)
    );

    // 50 MHz clock
    always #10 clk = ~clk;

    initial begin
        clk = 0; reset = 1; update = 0; sample_in = 0;
        #40 reset = 0;

        // Feed some test samples one at a time
        repeat(20) begin
            @(posedge clk);
            sample_in = $random;
            update = 1;
            @(posedge clk);
            update = 0;
            #20;
        end
        $stop;
    end

    initial begin
        $monitor("t=%0t in=%d out=%d", $time, sample_in, sample_out);
    end
endmodule

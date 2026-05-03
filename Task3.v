// Task 3: N-sample averaging FIR filter using circular queue + accumulator.
//
// To experiment with different N values:
//   Change N and LOG2_N together. N must be a power of 2.
//   Examples: N=8/LOG2_N=3, N=16/LOG2_N=4, N=32/LOG2_N=5, N=64/LOG2_N=6
//
// How it works (per Figure 6 in the lab spec):
//   1. Incoming sample is divided by N (arithmetic right shift by LOG2_N)
//   2. Divided sample is pushed into the circular FIFO queue
//   3. The new divided value is added to the accumulator
//   4. Once the FIFO is full, the oldest value popped from FIFO is added * -1
//      (i.e. subtracted), keeping the accumulator equal to the moving average
//
// Startup behaviour:
//   fill_count tracks how many samples are in the FIFO. For the first N samples
//   we do NOT subtract the oldest value (it hasn't wrapped yet), so the
//   accumulator ramps up correctly rather than subtracting uninitialised entries.

module task3 #(
    parameter N      = 8,  // Number of samples to average — must be power of 2
    parameter LOG2_N = 3   // log2(N)
)(
    input                  clk,
    input                  reset,
    input                  update,     // Pulse high 1 cycle per new sample (when CODEC ready)
    input  signed [23:0]   sample_in,
    output signed [23:0]   sample_out
);

    // -------------------------------------------------------------------------
    // Divide input by N: arithmetic right shift preserves sign for negative samples
    // Formula from lab spec: {{n{data[w-1]}}, data[w-1:n]}
    // -------------------------------------------------------------------------
    wire signed [23:0] divided;
    assign divided = {{LOG2_N{sample_in[23]}}, sample_in[23:LOG2_N]};

    // -------------------------------------------------------------------------
    // Circular queue of depth N storing divided samples
    // -------------------------------------------------------------------------
    reg signed [23:0]   queue [0:N-1];
    reg [$clog2(N)-1:0] head;        // index of oldest entry (next to be removed)
    reg [$clog2(N)-1:0] tail;        // index of next write position
    reg [$clog2(N):0]   fill_count;  // number of valid entries currently in queue

    wire signed [23:0] oldest = queue[head]; // value leaving the FIFO this cycle

    // -------------------------------------------------------------------------
    // Accumulator: running sum of the divided samples in the queue
    // -------------------------------------------------------------------------
    reg signed [23:0] accumulator;

    integer i;

    always @(posedge clk) begin
        if (reset) begin
            accumulator <= 24'sd0;
            head        <= 0;
            tail        <= 0;
            fill_count  <= 0;
            for (i = 0; i < N; i = i + 1)
                queue[i] <= 24'sd0;
        end else if (update) begin
            // Push new divided sample into queue at tail
            queue[tail] <= divided;
            tail <= (tail == N - 1) ? 0 : tail + 1;

            if (fill_count == N) begin
                // Queue full: proper moving average
                // Add new sample, add oldest * -1 (per lab spec Figure 6)
                accumulator <= accumulator + divided + (~oldest + 1'b1);
                head        <= (head == N - 1) ? 0 : head + 1;
            end else begin
                // Queue still filling up: just add new sample, no subtraction yet
                accumulator <= accumulator + divided;
                fill_count  <= fill_count + 1;
            end
        end
    end

    assign sample_out = accumulator;

endmodule

// Mentor wrapper only.
// Replace with the official F07 interface after HTML specification freeze.

module f07_rr_arbiter_wrapper (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [2:0] req,
    input  logic       done,
    output logic [2:0] grant,
    output logic       busy
);
    f07_rr_arbiter dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .done(done),
        .grant(grant),
        .busy(busy)
    );
endmodule

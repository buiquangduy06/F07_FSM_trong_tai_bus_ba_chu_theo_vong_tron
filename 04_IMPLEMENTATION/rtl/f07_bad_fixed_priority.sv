// EDUCATIONAL ANTI-PATTERN.
// Fixed priority is intentionally shown to contrast with round-robin.

module f07_bad_fixed_priority (
    input  logic [2:0] req,
    output logic [2:0] grant
);
    always_comb begin
        if      (req[0]) grant = 3'b001;
        else if (req[1]) grant = 3'b010;
        else if (req[2]) grant = 3'b100;
        else             grant = 3'b000;
    end
endmodule

// Optional SVA properties for simulators supporting assertions.
`ifdef F07_SVA
assert_onehot0: assert property (@(posedge clk) $onehot0(grant));
assert_grant_stable: assert property (@(posedge clk)
    busy && !done |=> grant == $past(grant));
`endif

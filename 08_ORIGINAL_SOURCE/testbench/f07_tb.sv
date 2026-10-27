module f07_tb;
    logic clk, rst_n, done;
    logic [2:0] req;
    logic [2:0] grant;
    logic busy;

    f07_rr_arbiter dut(
        .clk(clk), .rst_n(rst_n), .req(req), .done(done),
        .grant(grant), .busy(busy)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin @(posedge clk); #1; end
    endtask

    task automatic complete;
        begin
            done=1'b1;
            tick();
            done=1'b0;
        end
    endtask

    initial begin
        clk=0; rst_n=0; req=0; done=0;
        repeat(2) tick();
        rst_n=1;

        // No request.
        tick();
        assert(grant==3'b000 && !busy) else $fatal(1,"idle failure");

        // All three request continuously.
        req=3'b111;

        tick();
        assert(grant==3'b001) else $fatal(1,"expected M0 first");
        assert($onehot0(grant)) else $fatal(1,"grant not one-hot");

        complete();
        tick();
        assert(grant==3'b010) else $fatal(1,"expected M1 second");
        assert($onehot0(grant)) else $fatal(1,"grant not one-hot");

        complete();
        tick();
        assert(grant==3'b100) else $fatal(1,"expected M2 third");
        assert($onehot0(grant)) else $fatal(1,"grant not one-hot");

        complete();
        tick();
        assert(grant==3'b001) else $fatal(1,"round-robin did not wrap");

        // Grant must remain stable even if req changes while ACTIVE.
        req=3'b000;
        tick();
        assert(grant==3'b001 && busy) else $fatal(1,"active grant changed unexpectedly");

        complete();
        tick();
        assert(grant==3'b000 && !busy) else $fatal(1,"completion failed");

        // Single requester.
        req=3'b100;
        tick();
        assert(grant==3'b100) else $fatal(1,"single requester failed");

        complete();
        tick();
        assert(grant==3'b000) else $fatal(1,"single requester completion failed");

        // Reset recovery.
        rst_n=0;
        tick();
        rst_n=1;
        req=0;
        tick();
        assert(grant==0 && !busy) else $fatal(1,"reset recovery failed");

        $display("F07 TB completed");
        $finish;
    end
endmodule

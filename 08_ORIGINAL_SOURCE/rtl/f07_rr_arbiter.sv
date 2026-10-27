module f07_rr_arbiter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [2:0] req,
    input  logic       done,
    output logic [2:0] grant,
    output logic       busy
);

    typedef enum logic {IDLE, ACTIVE} state_t;
    state_t state;

    logic [1:0] ptr;
    logic [1:0] selected_id;
    logic [2:0] selected_grant;

    function automatic logic [2:0] onehot3(input logic [1:0] id);
        case (id)
            2'd0: onehot3 = 3'b001;
            2'd1: onehot3 = 3'b010;
            2'd2: onehot3 = 3'b100;
            default: onehot3 = 3'b000;
        endcase
    endfunction

    always_comb begin
        selected_id    = 2'd0;
        selected_grant = 3'b000;

        case (ptr)
            2'd0: begin
                if      (req[0]) begin selected_id=2'd0; selected_grant=3'b001; end
                else if (req[1]) begin selected_id=2'd1; selected_grant=3'b010; end
                else if (req[2]) begin selected_id=2'd2; selected_grant=3'b100; end
            end
            2'd1: begin
                if      (req[1]) begin selected_id=2'd1; selected_grant=3'b010; end
                else if (req[2]) begin selected_id=2'd2; selected_grant=3'b100; end
                else if (req[0]) begin selected_id=2'd0; selected_grant=3'b001; end
            end
            default: begin
                if      (req[2]) begin selected_id=2'd2; selected_grant=3'b100; end
                else if (req[0]) begin selected_id=2'd0; selected_grant=3'b001; end
                else if (req[1]) begin selected_id=2'd1; selected_grant=3'b010; end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            ptr   <= 2'd0;
            grant <= 3'b000;
            busy  <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    grant <= selected_grant;
                    busy  <= (selected_grant != 3'b000);
                    if (selected_grant != 3'b000)
                        state <= ACTIVE;
                end

                ACTIVE: begin
                    if (done) begin
                        // Advance priority according to the master actually served.
                        case (grant)
                            3'b001: ptr <= 2'd1;
                            3'b010: ptr <= 2'd2;
                            3'b100: ptr <= 2'd0;
                            default: ptr <= ptr;
                        endcase
                        grant <= 3'b000;
                        busy  <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    ptr   <= 2'd0;
                    grant <= 3'b000;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule

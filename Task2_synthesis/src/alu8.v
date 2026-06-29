module alu8 (
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [1:0] sel, // 00: ADD, 01: SUB, 10: AND, 11: OR
    output reg [7:0] result
);

    always @(*) begin
        case (sel)
            2'b00: result = a + b;       // Addition
            2'b01: result = a - b;       // Subtraction
            2'b10: result = a & b;       // Bitwise AND
            2'b11: result = a | b;       // Bitwise OR
            default: result = 8'h00;
        endcase
    end

endmodule

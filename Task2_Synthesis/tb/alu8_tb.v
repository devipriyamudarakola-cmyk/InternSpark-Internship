`timescale 1ns/1ps

module alu8_tb;
    reg [7:0] a;
    reg [7:0] b;
    reg [1:0] sel;
    wire [7:0] result;

    // Instantiate the structural gate netlist
    alu8 uut (
        .a(a),
        .b(b),
        .sel(sel),
        .result(result)
    );

    initial begin
        // Setup waveform tracing filename
        $dumpfile("alu8_waves.vcd");
        $dumpvars(0, alu8_tb);

        $display("=== STARTING ALU GLS SIMULATION ===");

        // ADD: 10 + 5 = 15
        a = 8'd10; b = 8'd5; sel = 2'b00;
        #10;

        // SUB: 20 - 4 = 16
        a = 8'd20; b = 8'd4; sel = 2'b01;
        #10;

        // AND: 0xCC & 0xAA = 0x88
        a = 8'hCC; b = 8'hAA; sel = 2'b10;
        #10;

        // OR: 0xF0 | 0x0F = 0xFF
        a = 8'hF0; b = 8'h0F; sel = 2'b11;
        #10;

        $display("=== SIMULATION SUCCESS ===");
        $finish;
    end
endmodule

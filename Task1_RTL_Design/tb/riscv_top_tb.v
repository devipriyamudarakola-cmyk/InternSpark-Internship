
// TESTBENCH FOR SINGLE CYCLE RISC-V CORE

`timescale 1ns / 1ps

module testbench;
    reg clk;
    reg reset;

    // Instantiate UUT (Unit Under Test)
    riscv_single_cycle uut (
        .clk(clk),
        .reset(reset)
    );

    // Clock Generator (10ns clock period)
    always #5 clk = ~clk;

    initial begin
        // Setup visual waveform dump for EPWave
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        // Display tracking header
        $display("Time\t PC\t\t Instruction");
        $monitor("%0d\t %h\t %h", $time, uut.PC, uut.instr);

        // Apply System Reset
        clk = 0;
        reset = 1;
        #12; // Release slightly after the edge
        reset = 0;

        // Allow enough runtime cycles for our program execution
        #120;
        
        // Final Register File State Validation
        $display("\n--- Final Register States Check ---");
        $display("x2 (Base Reg):       %0d", uut.regfile.registers[2]);
        $display("x3 (Loaded Val):     %0d", uut.regfile.registers[3]);
        $display("x4 (Addition Add):   %0d", uut.regfile.registers[4]);
        $display("x5 (Sub result):    %0d", uut.regfile.registers[5]);
        $display("x6 (Loaded from RAM):%0d", uut.regfile.registers[6]);
        
        $finish;
    end
endmodule

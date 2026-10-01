# riscv64xO3 synthesis constraints (SDC, 100 MHz nominal)
create_clock -name clk_i -period 10.0 [get_ports clk_i]
set_clock_uncertainty 0.25 [get_clocks clk_i]
set_input_delay 2.0 -clock clk_i [all_inputs]
set_output_delay 2.0 -clock clk_i [all_outputs]

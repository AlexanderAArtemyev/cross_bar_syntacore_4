// simple clock constraints
create_clock -period 3.000 -name clk -waveform {0.000 1.500} -add [get_ports -filter { NAME =~  "*clk*" && DIRECTION == "IN" }]
set_system_jitter 0.100




#**************************************************************
# Time Information
#**************************************************************

#set_time_format -unit ns -decimal_places 3

#**************************************************************
# Create Clock
#**************************************************************
create_clock -name {SYS_CLK} 	-period 4.000 -waveform { 0.000 2.000 } [get_ports {SYS_CLK}]


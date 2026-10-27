# F07 — STA (OpenSTA). Chay tu thu muc goc cua de:
#   sta -no_splash -exit 04_IMPLEMENTATION/scripts/03_run_sta.tcl
# Dat bien LIBERTY neu Liberty khong nam o duong dan mac dinh.
set lib_file $::env(LIBERTY)
read_liberty $lib_file
read_verilog 06_GDSII/synthesis/netlist.v
link_design f07_rr_arbiter
read_sdc 04_IMPLEMENTATION/constraints/design.sdc
report_checks -path_delay max -group_path_count 12 -format full_clock_expanded \
    -fields {slew cap input_pin net fanout} > 06_GDSII/sta/timing_report_max.txt
report_checks -path_delay min -group_path_count 5 > 06_GDSII/sta/timing_report_min.txt
report_checks -path_delay max -group_path_count 1 -format summary > 06_GDSII/sta/summary.txt
report_wns > 06_GDSII/sta/wns.txt
report_tns > 06_GDSII/sta/tns.txt
report_power > 06_GDSII/power/power_report.txt

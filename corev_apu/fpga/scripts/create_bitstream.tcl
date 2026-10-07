set project ariane
set script_file [info script]
set origin_dir [file dirname [file normalize "$script_file/../../../"]]

set nproc [auto_execok "nproc"]
set cores 8
if {[llength $nproc]} {
    if {![catch {exec $nproc "--all"} cores]} {
        if { $cores > 32 } {
            set_param general.maxThreads 32
        } else {
            set_param general.maxThreads $cores
        }
    }
}

open_project $project

# Run OOC module synthesis
generate_target all [get_files  "$origin_dir/corev_apu/fpga/ariane.srcs/sources_1/bd/SoC/SoC.bd"]
export_ip_user_files -of_objects [get_files "$origin_dir/corev_apu/fpga/ariane.srcs/sources_1/bd/SoC/SoC.bd"] -no_script -sync -force
create_ip_run [get_files -of_objects [get_fileset sources_1] "$origin_dir/corev_apu/fpga/ariane.srcs/sources_1/bd/SoC/SoC.bd"]

# Set for timing optimized implementation
set_property "steps.synth_design.args.global_retiming" "on" [get_runs synth_1]
#set_property "steps.place_design.args.directive" "ExtraPostPlacementOpt" [get_runs impl_1]
#set_property "steps.route_design.args.directive" "Explore" [get_runs impl_1]
#set_property "steps.phys_opt_design.args.directive" "AlternateFlowWithRetiming" [get_runs impl_1]

launch_runs [get_runs synth_1] -jobs $cores
wait_on_runs [get_runs synth_1]

# Launch synthesis
launch_runs synth_1 -jobs $cores
wait_on_run synth_1
open_run synth_1

launch_runs impl_1
wait_on_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
open_run impl_1

# Output Verilog netlist + SDC for timing simulation
write_verilog -force -mode funcsim work-fpga/${project}_funcsim.v
write_verilog -force -mode timesim work-fpga/${project}_timesim.v
write_sdf     -force work-fpga/${project}_timesim.sdf

# Write reports
exec mkdir -p reports/
exec rm -rf reports/*

check_timing -verbose                                                   -file reports/$project.check_timing.rpt
report_timing -max_paths 100 -nworst 100 -delay_type max -sort_by slack -file reports/$project.timing_WORST_100.rpt
report_timing -nworst 1 -delay_type max -sort_by group                  -file reports/$project.timing.rpt
report_utilization -hierarchical                                        -file reports/$project.utilization.rpt
report_cdc                                                              -file reports/$project.cdc.rpt
report_clock_interaction                                                -file reports/$project.clock_interaction.rpt

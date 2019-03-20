set design $::env(NF_PROJECT_NAME)

open_project project/$design.xpr
get_runs *
open_run synth_1
# TODO figure out how to open the right thing
#open_run impl_1


report_utilization -hierarchical

report_timing_summary -path_type summary

exit


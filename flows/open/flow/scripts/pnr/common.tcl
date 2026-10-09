# File:        common.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Shared procs for the place-and-route scripts: load a stage database and report a stage.

proc env_or {name default} {
  if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
  return $default
}

# libraries, constraints, wire RC and dont-use list (after the design is loaded)
proc sb_setup {} {
  read_sdc $::env(SDC_FILE)
  source $::env(SETRC_TCL)
  set_dont_use $::env(PNR_DONT_USE)
}

proc sb_read_libs {} {
  foreach lib [concat $::env(LIBS) [env_or MACRO_LIBS ""]] { read_liberty $lib }
}

# load the database a previous stage wrote
proc sb_load {odb} {
  sb_read_libs
  read_db $::env(OUT_DIR)/$odb
  sb_setup
}

# timing, area (and skew) into <stage>.rpt and the metrics JSON, under ORFS stage names
proc sb_report {stage {skew 0}} {
  set rpt $::env(OUT_DIR)/$stage.rpt
  utl::push_metrics_stage "${stage}__{}"
  report_tns_metric
  report_tns_metric -hold
  report_worst_slack_metric
  report_worst_slack_metric -hold
  report_design_area_metrics
  if {$skew} {
    report_clock_skew_metric
    report_clock_skew_metric -hold
  }
  utl::pop_metrics_stage
  report_design_area > $rpt
  report_worst_slack -max >> $rpt
  report_worst_slack -min >> $rpt
  report_tns >> $rpt
  if {$skew} { report_clock_skew >> $rpt }
  report_checks -path_delay max -fields {slew cap fanout} -format full_clock_expanded >> $rpt
  report_checks -path_delay min -fields {slew cap fanout} -format full_clock_expanded >> $rpt
  report_checks -unconstrained -path_delay max -group_path_count 1 >> $rpt
}

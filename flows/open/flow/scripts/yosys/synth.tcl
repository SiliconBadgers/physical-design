# File:        synth.tcl
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Yosys logic synthesis for one design on one platform. Inputs are environment variables from synth.env, written by the Makefile.

yosys -import   ;# makes every Yosys command callable as a plain Tcl command

proc env_or {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

set top          $::env(TOP)                      ;# top module
set out          [env_or OUT_DIR .]                ;# output directory
set lib          $::env(LIB_MAP)                   ;# Liberty file to map onto
set extra_libs   [env_or LIB_EXTRA ""]             ;# extra cell libraries (tie cells)
set macro_libs   [env_or MACRO_LIBS ""]            ;# hard macro Liberty files
set period_ps    $::env(CLOCK_PERIOD_PS)           ;# clock period (ps)
set delay_ps     [env_or ABC_DELAY_PS $period_ps]  ;# ABC delay target (ps)
set dont_use     [env_or DONT_USE ""]              ;# cell patterns synthesis must not use
set flatten      [env_or SYNTH_FLATTEN 1]          ;# 1 = flatten the hierarchy
set retime       [env_or SYNTH_RETIME 0]           ;# 1 = ABC retiming
set fsm          [env_or SYNTH_FSM 0]              ;# 1 = let Yosys re-encode FSMs
set abc_script   [env_or ABC_SCRIPT ""]            ;# custom ABC script (empty = default)
set adder        [env_or SYNTH_ADDER kogge-stone]  ;# kogge-stone, sklansky, han-carlson or ripple
set outbuf       [env_or SYNTH_OUTBUF 1]           ;# 1 = buffer every output bit

log "SB: top=$top  period=${period_ps}ps  abc-target=${delay_ps}ps  map-lib=[file tail $lib]  flatten=$flatten  retime=$retime  fsm=$fsm  adder=$adder"

# --- 1. read the design ---
set frontend [env_or RTL_FRONTEND slang]   ;# slang (SystemVerilog) or verilog
set rtl_files [env_or RTL_FILES ""]
set inc_args {}
foreach d [env_or RTL_INCDIRS ""] { lappend inc_args -I $d }
set def_args {}
foreach d [env_or RTL_DEFINES ""] { lappend def_args -D $d }
set param_args {}
foreach p [env_or RTL_PARAMS ""] { lappend param_args -G $p }

# library cells and macros as black boxes (ports only)
foreach l [concat [list $lib] $extra_libs] { read_liberty -lib $l }
foreach l $macro_libs { read_liberty -lib $l }

if {$frontend eq "slang"} {
    # SLANG_HIERARCHY=1 keeps modules, so (* keep_hierarchy *) ones survive
    set hier_args [expr {[env_or SLANG_HIERARCHY 0] ? {--best-effort-hierarchy} : {}}]
    read_slang --top $top {*}$hier_args {*}$inc_args {*}$def_args {*}$param_args {*}$rtl_files
} else {
    read_verilog -sv {*}$inc_args {*}$def_args {*}$rtl_files
    foreach p [env_or RTL_PARAMS ""] {
        lassign [split $p =] name value
        chparam -set $name $value $top
    }
}

# --- 2. check the hierarchy ---
hierarchy -check -top $top   ;# error on undefined modules

# --- 3. generic synthesis ---
# -nofsm keeps the RTL state encoding; -extra-map picks the adder architecture
set synth_args [list -top $top]
if {$flatten} { lappend synth_args -flatten }
if {!$fsm}    { lappend synth_args -nofsm }
switch -- $adder {
    ripple  { }
    kogge-stone - sklansky - han-carlson {
        lappend synth_args -extra-map +/choices/$adder.v
    }
    default { error "SYNTH_ADDER=$adder: use kogge-stone, sklansky, han-carlson or ripple" }
}
synth {*}$synth_args   ;# map to Yosys generic gates

# number of objects a selection matches
proc sb_count {args} {
    set f $::out/.sb_select.txt
    tee -q -o $f select -list {*}$args
    set fh [open $f]; set text [string trim [read $fh]]; close $fh
    file delete $f
    if {$text eq ""} { return 0 }
    return [llength [split $text "\n"]]
}
# number of problems reported by the last `check` in $file
proc sb_check_problems {file} {
    set fh [open $file]; set text [read $fh]; close $fh
    set n 0
    foreach {all count} [regexp -all -inline {Found and reported (\d+) problems} $text] { set n $count }
    return $n
}

# latch check, part 1: generic latches
if {[sb_count t:\$_DLATCH* t:\$_SR_* t:\$_DLATCHSR*] > 0} {
    select -list t:\$_DLATCH* t:\$_SR_* t:\$_DLATCHSR*
    log -stderr "SB-ERROR: synthesis inferred a latch (listed just above in synth.log):"
    log -stderr "          a combinational block does not assign a signal on every path."
    log -stderr "          Add a default assignment or a full case. See docs/reading_synth_logs.md"
    error "latch inferred"
}

# structural check, part 1: multiple drivers, undriven nets, loops (generic gates)
tee -o $out/synth_check.txt check
if {[sb_check_problems $out/synth_check.txt] > 0} {
    log -stderr "SB-ERROR: 'check' found structural problems (see synth_check.txt):"
    log -stderr "          multiple drivers, undriven nets, or combinational loops."
    error "check failed"
}

# --- 4. technology mapping (ABC -D is in ps) ---
set du_args {}
foreach pattern $dont_use { lappend du_args -dont_use $pattern }

if {$retime} {
    abc -dff -D $delay_ps   ;# retiming: move flip-flops across logic
}

dfflibmap -liberty $lib {*}$du_args   ;# map flip-flops to library cells

set abc_args [list -liberty $lib -D $delay_ps {*}$du_args]
set constr [env_or ABC_CONSTR_FILE ""]
if {$constr ne ""} {
    # input driver and output load for ABC
    lappend abc_args -constr $constr
}
if {$abc_script ne ""} {
    # a custom script needs {D} to get the delay target
    set fh [open $abc_script]; set body [read $fh]; close $fh
    if {[string first "{D}" $body] < 0} {
        log -stderr "SB-WARNING: ABC_SCRIPT $abc_script has no {D}: the delay target (-D $delay_ps) is ignored"
    }
    lappend abc_args -script $abc_script
}
set sub_frac [env_or ABC_SUBMODULE_DELAY_FRAC 1.0]   ;# share of the target for (* keep_hierarchy *) modules
if {$sub_frac < 1.0} {
    set sub_ps [expr {int($delay_ps * $sub_frac)}]
    set i [lsearch -exact $abc_args -D]
    abc {*}[lreplace $abc_args [expr {$i + 1}] [expr {$i + 1}] $sub_ps] A:keep_hierarchy   ;# kept modules
    abc {*}$abc_args A:keep_hierarchy %n   ;# everything else
} else {
    abc {*}$abc_args   ;# map logic to library gates
}

# --- 5. clean up the netlist ---
if {$outbuf} {
    iopadmap -bits -outpad $::env(BUF_CELL) $::env(BUF_IN):$::env(BUF_OUT) $top   ;# buffer every output bit
}

setundef -zero   ;# undefined bits (x) to 0

# constants from tie cells, one per value
hilomap -singleton -hicell $::env(TIEHI_CELL) $::env(TIEHI_PORT) \
                   -locell $::env(TIELO_CELL) $::env(TIELO_PORT)

splitnets   ;# split internal buses into bits

opt_clean -purge   ;# remove unused wires and cells

# buffer cells instead of port-to-port assigns
insbuf -buf $::env(BUF_CELL) $::env(BUF_IN) $::env(BUF_OUT)

# --- 6. structural check, part 2 (mapped netlist) ---
tee -a $out/synth_check.txt check
if {[sb_check_problems $out/synth_check.txt] > 0} {
    log -stderr "SB-ERROR: 'check' found structural problems (see synth_check.txt):"
    log -stderr "          multiple drivers, undriven nets, or combinational loops."
    error "check failed"
}

# --- 7. latch check, part 2: no library latch cells ---
set latch_sel {}
foreach pattern [env_or LATCH_CELLS ""] { lappend latch_sel t:$pattern }
if {[llength $latch_sel] > 0} {
    if {[sb_count {*}$latch_sel] > 0} {
        log -stderr "SB-ERROR: the mapped netlist contains latch cells ([env_or LATCH_CELLS {}])."
        error "latch cells in netlist"
    }
}

# --- 8. reports and netlist ---
set stat_args {}
foreach l [concat [list $lib] $extra_libs $macro_libs] { lappend stat_args -liberty $l }
tee -o $out/synth_stat.txt stat {*}$stat_args   ;# cell area (um^2) from Liberty
tee -q -o $out/synth_stat.json stat -json {*}$stat_args
# keep only the JSON object (tee also captures log lines)
set fh [open $out/synth_stat.json]; set txt [read $fh]; close $fh
set fh [open $out/synth_stat.json w]
puts -nonewline $fh [string range $txt [string first "\{" $txt] end]
close $fh

write_verilog -noattr -noexpr -nohex -nodec $out/netlist.v   ;# plain cell instances only
log "SB: wrote $out/netlist.v"

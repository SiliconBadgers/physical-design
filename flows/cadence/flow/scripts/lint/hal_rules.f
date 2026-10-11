// File:        hal_rules.f
// Author:      Isaac Hagedorn
// Date:        2026-10-11
// Description: HAL rules make lint turns off (xrun -f, the default HAL_ARGS). Each fires on correct, readable RTL and buries the real findings.
//              Same list as synth-onboarding's flow/xcelium/hal_rules.f.
//              Kept on, among others: latches (LATINF, LATBAS, LATMLG), multiple drivers (MLTDRV), loops (CMBPAU, COMBLP),
//              sensitivity lists (SENCMW, OLDALW), unused or undriven signals (URDREG, USEPRT, UNDRIV), width loss.

// layout and naming
-nocheck MAXLEN    // line longer than 80 characters
-nocheck SEPLIN    // two statements on one line
-nocheck NOBLKN    // unnamed begin/end block
-nocheck NBGEND    // if/else without begin/end
-nocheck STYVAL    // numbers in widths ([7:0]) instead of named constants
-nocheck DIFFMN    // module name differs from the file name
-nocheck MULTMF    // more than one module in a file
-nocheck LCVARN    // uppercase letters in a module name
-nocheck UCCONN    // lowercase letters in a constant name
-nocheck NUMSUF    // identifier ends in a number
-nocheck KEYWOD    // VHDL keyword used as a Verilog name
-nocheck ONPNSG    // one-bit signal declared as a bus
-nocheck BOUINC    // array range that does not start at 0
-nocheck TDOPKG    // typedef outside a package
-nocheck HASUPC    // unique case used
-nocheck CDEFCV    // default branch of a full case
-nocheck EMPBLK    // empty begin/end block
-nocheck EMPSTM    // empty statement
-nocheck MICAWS    // several if/case statements in one always block
-nocheck DNSTIF    // deeply nested if/else
-nocheck MULBAS    // several blocking assignments to one variable (default value, then override)
-nocheck VARUAW    // logic port driven by an assign
-nocheck DFDRVS    // vector slices driven by different kinds of statements (generate loops)
-nocheck REVROP    // always_comb result read by an assign
-nocheck EXPIPC    // expression on an instance port
-nocheck IPRTEX    // constant on an instance port
-nocheck INDXOP    // arithmetic in an array index
// preprocessor and literals
-nocheck CDWARN    // `ifdef used
-nocheck NODEFD    // `define used
-nocheck NOUNDF    // `define without `undef
-nocheck IFDDEF    // `define and `ifdef in one file
-nocheck USEMAC    // macro defined but not used
-nocheck LEXPGM    // lexical pragma in the file
-nocheck TPRUSD    // translate_off pragma
-nocheck PRMBSE    // parameter value without a base ('d, 'h)
-nocheck PRMVAL    // parameter without a width
-nocheck CONSBS    // constant without a base
-nocheck BITUNS    // sized constant with not every bit written out ('0 style)
// widths and signs that lose nothing (an increment by 1'b1, '0 into a signed, a lossless truncation)
-nocheck PADMSB    // constant zero-padded to the other operand's width
-nocheck UELOPR    // operands of + or - of different widths
-nocheck IPSFOU    // '0 converted to signed
-nocheck IMPDTC    // integer literal converted to unsigned
-nocheck IMPTYP    // integer expression converted to a vector
-nocheck TRUNCZ    // truncation that loses no bits
-nocheck POIASG    // every adder and multiplier "may overflow"
-nocheck LRGOPR    // arithmetic on wide operands
// design structure: partitioning and coding style choices, not errors
-nocheck CBPAHI    // combinational path through several modules (an error in HAL, a style rule)
-nocheck SYNPRT    // combinational output port
-nocheck TPOUNR    // top-level output not driven by a register
-nocheck ATLGLC    // logic in the top-level module
-nocheck IOCOMB    // combinational path from an input to an output
-nocheck FDTHRU    // input passed straight to an output
-nocheck DALIAS    // two wires with the same driver
-nocheck DIFCLK    // clock named differently in a submodule
-nocheck DIFRST    // reset named differently in a submodule
-nocheck SYNASN    // module with both synchronous and asynchronous logic
-nocheck FFWNSR    // flip-flop without set or reset (datapath registers)
-nocheck FFWASR    // flip-flop without an asynchronous set or reset
-nocheck TIELOG    // output tied to a constant
-nocheck MXFNOT    // port fanout above 10 (fanout is a synthesis and layout topic)
// reset synchronizer: these describe exactly what a two-flop synchronizer is
-nocheck FFCSTD    // flip-flop with a constant data input
-nocheck FRSTDF    // reset driven by a flip-flop
-nocheck RSTGNH    // reset generated below the modules it resets
-nocheck RSTGNP    // reset generation in a module with other logic
-nocheck RSTINP    // reset that is not a module input
// FSM coding style
-nocheck BADFSM    // FSM not in HAL's preferred style
-nocheck EXTFSM    // other logic in an FSM module
-nocheck EXTSEQ    // other logic in an FSM's sequential block
-nocheck LMTSTS    // more than 40 states
-nocheck TRNMBT    // state transition flips more than one bit
// information only
-nocheck VLGMEM    // Verilog memory present
-nocheck LOOPTM    // loop with more than 10 iterations
-nocheck BADSYS    // $display ignored by synthesis

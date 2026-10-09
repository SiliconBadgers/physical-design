# File:        gds.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: KLayout script that merges a routed DEF with the cell layouts into one GDS (make gds GDS_TOOL=klayout).
# Run: klayout -zz -rd in_def=<def> -rd lefs="<lef ...>" -rd gds_in="<gds ...>" -rd lyt=<lyt> -rd top=<top> -rd out=<gds> -r gds.py
import pya

tech = pya.Technology()
tech.load(lyt)
opts = tech.load_layout_options
opts.lefdef_config.lef_files = lefs.split()

layout = pya.Layout()
layout.read(in_def, opts)
top_cell = layout.cell(top)

# empty the LEF abstracts so the cell GDS fills them in
for cell in layout.each_cell():
    if cell.cell_index() != top_cell.cell_index() and not cell.name.startswith("VIA_"):
        cell.clear()
for f in gds_in.split():
    layout.read(f)

# write only the design's cell tree
merged = pya.Layout()
merged.dbu = layout.dbu
merged.create_cell(top).copy_tree(top_cell)
empty = [c.name for c in merged.each_cell() if c.is_empty()]
if empty:
    raise RuntimeError("cells with no layout: " + " ".join(sorted(empty)))
merged.write(out)
print(f"wrote {out}")

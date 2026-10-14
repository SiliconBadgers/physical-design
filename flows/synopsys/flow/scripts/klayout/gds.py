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
merged_top = merged.create_cell(top)
merged_top.copy_tree(top_cell)
empty = [c.name for c in merged.each_cell() if c.is_empty()]
if empty:
    raise RuntimeError("cells with no layout: " + " ".join(sorted(empty)))

# close sub-minimum metal holes (m1.7 / m2.7: min. metal hole area 0.14 um2). A hole is
# interior to a single net's polygon, so filling it adds same-net metal and changes no
# connectivity (LVS is unaffected); the detailed router can leave such tiny holes where
# pins meet rails or power straps. Patches are added at the top level over the flat view.
min_hole = 0.14 / (merged.dbu * merged.dbu)
for layer_num, datatype in ((68, 20), (69, 20)):   # met1, met2
    li = merged.find_layer(layer_num, datatype)
    if li is None:
        continue
    region = pya.Region(merged_top.begin_shapes_rec(li))
    region.merge()
    patches = pya.Region()
    for hole in region.holes().each():
        if hole.area() < min_hole:
            patches.insert(hole)
    if not patches.is_empty():
        patches.merge()
        merged_top.shapes(li).insert(patches)
        print(f"healed {patches.count()} sub-min hole(s) on layer {layer_num}/{datatype}")

merged.write(out)
print(f"wrote {out}")

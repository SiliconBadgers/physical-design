# File:        pin_metal.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: KLayout script that draws metal (datatype 20) under every pin shape (datatype 16) of the top cell, so a wire that ends at a pin of this design connects. Rewrites the GDS in place.
# Run: klayout -zz -rd gds=<gds> -rd top=<top> -r pin_metal.py
import pya

layout = pya.Layout()
layout.read(gds)
top_cell = layout.cell(top)
if top_cell is None:
    raise RuntimeError(f"no cell {top} in {gds}")

count = 0
for li in list(layout.layer_indexes()):
    info = layout.get_info(li)
    if info.datatype == 16:
        drawing = layout.layer(info.layer, 20)
        for shape in top_cell.shapes(li).each(pya.Shapes.SBoxes | pya.Shapes.SPolygons | pya.Shapes.SPaths):
            top_cell.shapes(drawing).insert(shape)
            count += 1
layout.write(gds)
print(f"pin_metal: {count} pin shape(s) of {top} drawn on datatype 20 -> {gds}")

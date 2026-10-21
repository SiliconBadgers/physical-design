# File:        abstract_gds.py
# Author:      Isaac Hagedorn
# Date:        2026-10-09
# Description: KLayout script that writes the GDS of a design for use as a macro. Library cells keep their names; every other cell below the top gets the prefix <top>_ so it cannot clash with a cell of the design that uses the macro.
# Run: klayout -zz -rd in_gds=<gds> -rd cells_gds="<gds ...>" -rd top=<top> -rd out=<gds> -r abstract_gds.py
import pya

lib_cells = set()
for f in cells_gds.split():
    lib = pya.Layout()
    lib.read(f)
    lib_cells.update(c.name for c in lib.each_cell())

layout = pya.Layout()
layout.read(in_gds)
top_cell = layout.cell(top)
if top_cell is None:
    raise RuntimeError(f"no cell {top} in {in_gds}")

renamed = 0
for cell in layout.each_cell():
    if cell.cell_index() != top_cell.cell_index() and cell.name not in lib_cells:
        cell.name = f"{top}_{cell.name}"
        renamed += 1
layout.write(out)
print(f"abstract_gds: {renamed} cell(s) renamed with prefix {top}_ -> {out}")

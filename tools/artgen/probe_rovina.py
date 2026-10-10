# -*- coding: utf-8 -*-
"""probe_rovina.py - jak je VELKA rovina z `primitive_grid_add(size=1.0)`?

Sonda vznikla z rozporu: stin mel sedet na dlazdici 1x1 jednotky, ale v renderu
byla rovina SIRSI (zmereno 497 px na polovinu uhlopricky pri 704 px/jednotku,
coz je 1,41 jednotky = odmocnina ze 2). Kdo veri nazvu parametru, vyrobi stin
na 2x vetsi plose - a nikdo to nepozna, dokud se to nezmeri.
"""
from __future__ import annotations

import bpy

bpy.ops.wm.read_factory_settings(use_empty=True)
for popis, kwargs in (("size=1.0, 1x1", {"size": 1.0, "x_subdivisions": 1,
                                         "y_subdivisions": 1}),
                      ("size=2.0, 2x2", {"size": 2.0, "x_subdivisions": 2,
                                         "y_subdivisions": 2}),
                      ("size=1.0, 2x2", {"size": 1.0, "x_subdivisions": 2,
                                         "y_subdivisions": 2})):
    bpy.ops.mesh.primitive_grid_add(location=(0.0, 0.0, 0.0), **kwargs)
    o = bpy.context.object
    xs = [v.co.x for v in o.data.vertices]
    ys = [v.co.y for v in o.data.vertices]
    print(f"ROVINA {popis}: x {min(xs):.4f}..{max(xs):.4f} ({max(xs) - min(xs):.4f}) "
          f"y {min(ys):.4f}..{max(ys):.4f} ({max(ys) - min(ys):.4f}) "
          f"vrcholu={len(o.data.vertices)} plocha={o.dimensions.x * o.dimensions.y:.4f}")
    bpy.data.objects.remove(o)
print("PROBE_OK")

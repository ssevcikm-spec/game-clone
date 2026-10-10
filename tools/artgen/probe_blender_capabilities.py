# -*- coding: utf-8 -*-
"""probe_blender_capabilities.py - CO UMÍ tenhle Blender (pro 2x vetev).

Neni to pipeline, je to sonda: ptá se na atributy, o kterych se jen hada
(EEVEE ambient occlusion, Cycles shadow catcher, dostupne engine).
Vypisuje `CAP=<jmeno>=<hodnota>` radky, aby se dalo grepovat.
"""
from __future__ import annotations

import bpy

print("CAP=verze=" + bpy.app.version_string)
bpy.ops.wm.read_factory_settings(use_empty=True)
s = bpy.context.scene

engines = [i.identifier for i in
           bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
print("CAP=engines=" + ",".join(engines))

s.render.engine = "BLENDER_EEVEE"
ee = s.eevee
for name in ("use_gtao", "gtao_distance", "gtao_factor", "use_raytracing",
             "use_fast_gi", "fast_gi_method", "fast_gi_distance",
             "fast_gi_ray_count", "fast_gi_step_count", "fast_gi_quality",
             "fast_gi_thickness_near", "fast_gi_thickness_far",
             "use_shadows", "shadow_ray_count", "shadow_step_count",
             "taa_render_samples", "use_volumetric_lights"):
    print(f"CAP=eevee.{name}={getattr(ee, name, 'NEEXISTUJE')}")

rt = getattr(ee, "ray_tracing_options", None)
if rt is not None:
    print("CAP=eevee.ray_tracing_options=" +
          ",".join(sorted(a for a in dir(rt) if not a.startswith("_"))))

s.render.engine = "CYCLES"
try:
    print(f"CAP=cycles.samples={s.cycles.samples}")
    print(f"CAP=cycles.use_denoising={s.cycles.use_denoising}")
    print(f"CAP=cycles.device={s.cycles.device}")
except Exception as e:  # noqa: BLE001
    print(f"CAP=cycles=CHYBA {e}")

o = bpy.data.objects.new("T", None)
print(f"CAP=object.is_shadow_catcher={hasattr(o, 'is_shadow_catcher')}")
print("CAP=KONEC")

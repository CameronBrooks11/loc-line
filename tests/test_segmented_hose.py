"""Render hose segments and check their size, how two fit together, and the refusals.

usage: python3 tests/test_segmented_hose.py [OPENSCAD]

- A segment renders as one solid, coupling_diameter + 2 x thickness across
  and segmented_hose_height() tall, standing on z = 0.
- Two segments one pitch apart: with a positive clearance, the second's ball
  sits in the first's socket without overlapping it (their intersection is
  empty); with a negative one, they overlap.
- The socket's mouth is narrower than the ball, so a ball that snaps in stays
  in; a segment whose mouth would let the ball fall out is refused.
"""

import json
import os
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "segmented_hose.scad")


def solids(path):
    data = open(path, "rb").read()
    (n,) = struct.unpack_from("<I", data, 80)
    tris = [struct.unpack_from("<9f", data, 84 + i * 50 + 12) for i in range(n)]
    parent = {}

    def find(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for t in tris:
        corners = [t[0:3], t[3:6], t[6:9]]
        for c in corners:
            parent.setdefault(c, c)
        root = find(corners[0])
        for c in corners[1:]:
            parent[find(c)] = root
    groups = {}
    for v in parent:
        groups.setdefault(find(v), []).append(v)
    return [([min(p[i] for p in g) for i in range(3)], [max(p[i] for p in g) for i in range(3)])
            for g in groups.values()]


def run(openscad, source, out, tmp):
    path = os.path.join(tmp, "probe.scad")
    with open(path, "w") as f:
        # A used file's top-level $fn doesn't reach its modules, so set the model file's here.
        f.write(f"use <{LIB}>\n$fn = 128;\n" + source)
    cmd = [openscad, "--hardwarnings", "-o", out]
    if out.endswith(".stl"):
        cmd += ["--export-format", "binstl"]
    return subprocess.run(cmd + [path], capture_output=True, text=True)


def echoes(result):
    return [json.loads(l.split("ECHO: ", 1)[1]) for l in result.stderr.splitlines() if l.startswith("ECHO: ")]


SIZES = [
    ("default", {}),
    ("larger, thicker wall", {"coupling_diameter": 20, "thickness": 2, "bore": 10}),
    ("smaller, narrow bore", {"coupling_diameter": 8, "bore": 3, "slit_dim": 1}),
]

results = []


def check(label, ok, got):
    results.append(bool(ok))
    print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")


def args(params):
    return ", ".join(f"{k} = {v}" for k, v in params.items())


def main():
    openscad = sys.argv[1] if len(sys.argv) > 1 else "openscad"
    with tempfile.TemporaryDirectory() as tmp:
        stl = os.path.join(tmp, "out.stl")
        csg = os.path.join(tmp, "out.csg")
        for label, params in SIZES:
            a = args(params)
            r = run(openscad, f"echo([segmented_hose_height({args({k: v for k, v in params.items() if k in ('coupling_diameter', 'thickness')})}), "
                    f"segmented_hose_pitch({args({k: v for k, v in params.items() if k == 'coupling_diameter'})}), "
                    f"segmented_hose_mouth({args({k: v for k, v in params.items() if k in ('coupling_diameter', 'thickness')})})]);\n", csg, tmp)
            height, pitch, mouth = echoes(r)[0]
            d = params.get("coupling_diameter", 12)
            across = d + 2 * params.get("thickness", 1)

            r = run(openscad, f"segmented_hose_segment({a});\n", stl, tmp)
            bad = [l for l in r.stderr.splitlines() if "WARNING" in l or "ERROR" in l]
            if r.returncode != 0 or bad:
                check(f"{label}: one segment", False, bad[:1] or f"exit {r.returncode}")
                continue
            parts = solids(stl)
            (lo, hi) = parts[0]
            size = [hi[i] - lo[i] for i in range(3)]
            ok = len(parts) == 1 and abs(lo[2]) < 0.01 and abs(size[0] - across) < 0.01 and abs(size[2] - height) < 0.01
            check(f"{label}: one segment", ok,
                  f"{len(parts)} solid(s), {size[0]:.2f} across, {size[2]:.2f} tall from z = {lo[2]:.2f}; want {across:g}, {height:g}")

            check(f"{label}: mouth narrower than the ball", mouth < d, f"mouth {mouth:.2f} mm, ball {d:g} mm")

            for clearance, want_empty in ((0.2, True), (-0.2, False)):
                both = args({**params, "clearance": clearance})
                r = run(openscad, f"intersection() {{ segmented_hose_segment({both}); "
                        f"translate([0, 0, {pitch}]) segmented_hose_segment({both}); }}\n", stl, tmp)
                empty = r.returncode != 0 and "top level object is empty" in r.stderr
                verb = "clears the socket" if want_empty else "overlaps the socket"
                check(f"{label}: next ball {verb} at clearance {clearance}", empty == want_empty,
                      "empty" if empty else "they overlap")

        for label, params, message in [
            # A socket as big as the ball always keeps it; a loose one cut low lets it out.
            ("refuses a mouth the ball falls out of", {"bottom_cut_factor": 0.55, "clearance": 0.5}, "would fall out"),
            ("refuses a bore with no wall", {"bore": 10}, "leaves no wall"),
        ]:
            r = run(openscad, f"segmented_hose_segment({args(params)});\n", stl, tmp)
            errors = [l for l in r.stderr.splitlines() if "ERROR" in l]
            check(label, errors and message in errors[0], errors[0][:110] if errors else f"exit {r.returncode}")

    print(f"{sum(results)} of {len(results)} checks passed")
    sys.exit(0 if all(results) else 1)


main()

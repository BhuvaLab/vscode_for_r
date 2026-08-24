"""cplot Python bootstrap: injects cp() then runs the recipe as __main__."""
import json, os, runpy, sys

import matplotlib
matplotlib.use("Agg")

STAGE = os.environ["CPLOT_STAGE"]
BASE  = os.environ["CPLOT_NAME"]
W     = float(os.environ.get("CPLOT_W", 8))
H     = float(os.environ.get("CPLOT_H", 5))
DPI   = float(os.environ.get("CPLOT_DPI", 150))
SVG   = bool(os.environ.get("CPLOT_SVG"))

def _emit(name, png, svg, w, h, dpi):
    with open(os.path.join(STAGE, "emitted.jsonl"), "a") as f:
        f.write(json.dumps({"name": name, "png": png, "svg": svg,
                            "w": w, "h": h, "dpi": dpi}) + "\n")

def _save(obj, path, w, h, dpi):
    import matplotlib.pyplot as plt
    # plotnine / anything exposing .save(filename=...)
    if hasattr(obj, "save") and not hasattr(obj, "savefig"):
        obj.save(path, width=w, height=h, dpi=dpi, verbose=False); return
    fig = obj
    if fig is None:
        fig = plt.gcf()
    if hasattr(fig, "figure") and not hasattr(fig, "savefig"):
        fig = fig.figure                       # Axes -> Figure
    if hasattr(fig, "get_figure") and not hasattr(fig, "savefig"):
        fig = fig.get_figure()
    fig.set_size_inches(w, h)
    fig.savefig(path, dpi=dpi, bbox_inches="tight", facecolor="white")

def cp(plot=None, suffix=None, svg=None, width=None, height=None, dpi=None):
    name = BASE if suffix is None else f"{BASE}-{suffix}"
    w = float(width or W); h = float(height or H); d = float(dpi or DPI)
    png = os.path.join(STAGE, name + ".png")
    _save(plot, png, w, h, d)
    sp = None
    if (SVG if svg is None else svg):
        sp = os.path.join(STAGE, name + ".svg")
        try: _save(plot, sp, w, h, d)
        except Exception: sp = None
        if sp and not os.path.exists(sp): sp = None
    _emit(name, png, sp, w, h, d)
    return png

if __name__ == "__main__":
    recipe = sys.argv[1]
    sys.argv = [recipe]
    runpy.run_path(recipe, init_globals={"cp": cp}, run_name="__main__")

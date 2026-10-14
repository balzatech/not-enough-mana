"""Agrega las lineas PERF de perf_final.gd: media, sd, min, max por (modo, jugadores, ancho).
Uso: python3 -I tests/perf/aggregate_final.py salida.txt [--json]"""
import json, sys, statistics as st, collections

def flat(d, pre=""):
    for k, v in d.items():
        if isinstance(v, dict):
            yield from flat(v, pre + k + ".")
        elif isinstance(v, list):
            if v and all(isinstance(x, dict) for x in v):
                for i, x in enumerate(v):
                    yield from flat(x, f"{pre}{k}[{i}].")
        elif isinstance(v, bool):
            yield pre + k, float(v)
        elif isinstance(v, (int, float)):
            yield pre + k, float(v)

def load(path):
    g = collections.defaultdict(list)
    for line in open(path):
        if line.startswith("PERF "):
            d = json.loads(line[5:])
            g[(d["mode"], d["players"], d["w"])].append(dict(flat(d)))
    return g

def agg(g):
    out = {}
    for k, rs in g.items():
        keys = sorted(set().union(*[r.keys() for r in rs]))
        out[k] = {m: [r[m] for r in rs if m in r] for m in keys}
    return out

if __name__ == "__main__":
    g = load(sys.argv[1])
    for k in sorted(g):
        rs = g[k]
        print(f"== modo={k[0]} jugadores={k[1]} ancho={k[2]} n={len(rs)}")
        for m in sorted(set().union(*[r.keys() for r in rs])):
            v = [r[m] for r in rs if m in r]
            sd = st.stdev(v) if len(v) > 1 else 0.0
            print(f"  {m}: media {st.mean(v):.3f} sd {sd:.3f} min {min(v):.3f} max {max(v):.3f}")

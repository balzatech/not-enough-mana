import json, sys, statistics as st, collections
g = collections.defaultdict(list)
for line in open(sys.argv[1]):
    if line.startswith("PERF "):
        d = json.loads(line[5:])
        g[(d["players"], d["w"], d["mode"])].append(d)
keys = ["frame_ms_p50","frame_ms_p95","frame_ms_max","active_frames","active_ms_p50","active_ms_p95","active_ms_max",
        "render_gpu_ms_p50","render_gpu_ms_p95","draw_calls_p50","human_submit_ms_mean","refresh_ms","reduce_ms",
        "legal_actions_ms","bot_decision_ms","view_for_ms","validate_state_ms","instantiate_ms","bind_first_refresh_ms",
        "table_nodes","nodes_total","tex_mem_after_load_mb","static_mem_end_mb","vram_mb","rev"]
for k in sorted(g):
    rs = g[k]
    print(f"== jugadores={k[0]} ancho={k[1]} modo={k[2]} n={len(rs)}")
    for m in keys:
        v = [r[m] for r in rs]
        sd = st.stdev(v) if len(v) > 1 else 0
        print(f"  {m}: media {st.mean(v):.3f} sd {sd:.3f} min {min(v):.3f} max {max(v):.3f}")

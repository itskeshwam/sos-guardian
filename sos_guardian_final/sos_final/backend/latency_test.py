#!/usr/bin/env python3
"""
SOS Guardian — Latency Benchmark
Run under 3 network conditions (Wi-Fi, 4G, 5G).
Each run captures T0, T1, T2 and calculates:
  Network latency    = T1 - T0
  Processing latency = T2 - T1
  Total E2E          = T2 - T0

Usage:
  python latency_test.py --runs 20 --label WiFi
  python latency_test.py --runs 20 --label 4G-LTE
  python latency_test.py --stress 100
"""
import argparse
import asyncio
import json
import statistics
import sys
import time
import uuid

import httpx

BASE_URL  = "http://localhost:8000"
DEVICE_ID = f"bench-{uuid.uuid4().hex[:8]}"
USERNAME  = "latency_tester"


def register(client: httpx.Client) -> bool:
    try:
        r = client.post(f"{BASE_URL}/v1/register", json={
            "username":  USERNAME,
            "device_id": DEVICE_ID,
        }, timeout=10)
        return r.status_code in (200, 201)
    except Exception as e:
        print(f"  Registration failed: {e}")
        return False


def send_one(client: httpx.Client) -> dict:
    t0 = int(time.time() * 1000)
    r = client.post(f"{BASE_URL}/v1/sos", json={
        "device_id":    DEVICE_ID,
        "sos_type":     "manual",
        "latitude":     18.5204,
        "longitude":    73.8567,
        "battery":      85,
        "t0_client_ms": t0,
    }, timeout=30)
    data = r.json()
    lat  = data.get("latency", {})
    return {
        "status":      r.status_code,
        "net_ms":      lat.get("network_ms"),
        "proc_ms":     lat.get("processing_ms"),
        "e2e_ms":      lat.get("e2e_ms"),
        "payload_bytes": lat.get("payload_bytes"),
        "session_id":  data.get("session_id"),
    }


def run_benchmark(runs: int, label: str):
    print(f"\n{'='*62}")
    print(f"  Condition: {label}   |   Runs: {runs}")
    print(f"{'='*62}")

    with httpx.Client() as client:
        if not register(client):
            print("  ERROR: Could not register. Is the server running?")
            sys.exit(1)

        results = []
        for i in range(1, runs + 1):
            try:
                r = send_one(client)
                ok = "✓" if r["status"] == 201 else "✗"
                print(
                    f"  {i:02d} {ok}  "
                    f"Net={r['net_ms']}ms  Proc={r['proc_ms']}ms  "
                    f"E2E={r['e2e_ms']}ms  {r['payload_bytes']}B"
                )
                if r["e2e_ms"] is not None:
                    results.append(r)
            except Exception as e:
                print(f"  {i:02d} ✗  Error: {e}")

    if not results:
        print("  No valid results.")
        return

    net   = [r["net_ms"]  for r in results if r["net_ms"]  is not None]
    proc  = [r["proc_ms"] for r in results if r["proc_ms"] is not None]
    e2e   = [r["e2e_ms"]  for r in results if r["e2e_ms"]  is not None]
    sizes = [r["payload_bytes"] for r in results if r["payload_bytes"]]

    def row(name, vals):
        if not vals:
            return
        print(f"  │  {name:<28} avg={statistics.mean(vals):.1f}ms  "
              f"min={min(vals)}ms  max={max(vals)}ms")

    print(f"\n  ┌─ RESULTS ({label}) ────────────────────────────────┐")
    row("Network Latency  (T1−T0)", net)
    row("Processing       (T2−T1)", proc)
    row("Total E2E        (T2−T0)", e2e)
    if sizes:
        print(f"  │  {'Payload Size':<28} avg={statistics.mean(sizes):.0f}B  "
              f"({statistics.mean(sizes)/1024:.2f} KB)")
    print(f"  │  {'Samples':<28} {len(results)}/{runs}")
    print(f"  └───────────────────────────────────────────────────┘")


async def run_stress(count: int):
    print(f"\n{'='*62}")
    print(f"  STRESS TEST: {count} concurrent SOS requests")
    print(f"{'='*62}")

    with httpx.Client() as client:
        register(client)

    async def one():
        t0 = int(time.time() * 1000)
        async with httpx.AsyncClient() as ac:
            r = await ac.post(f"{BASE_URL}/v1/sos", json={
                "device_id":    DEVICE_ID,
                "sos_type":     "manual",
                "latitude":     18.5204,
                "longitude":    73.8567,
                "t0_client_ms": t0,
            }, timeout=30)
            return r.status_code, r.elapsed.total_seconds() * 1000

    start   = time.time()
    tasks   = [one() for _ in range(count)]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    elapsed = (time.time() - start) * 1000

    ok    = sum(1 for r in results if not isinstance(r, Exception) and r[0] == 201)
    times = [r[1] for r in results if not isinstance(r, Exception)]

    print(f"  Successful      : {ok}/{count}")
    print(f"  Total elapsed   : {elapsed:.0f} ms")
    if times:
        print(f"  Avg resp time   : {statistics.mean(times):.1f} ms")
    print(f"  Throughput      : {count/(elapsed/1000):.1f} req/s")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--url",    default="http://localhost:8000")
    p.add_argument("--runs",   type=int, default=20)
    p.add_argument("--label",  default="WiFi")
    p.add_argument("--stress", type=int, default=0)
    args = p.parse_args()
    BASE_URL = args.url

    if args.stress:
        asyncio.run(run_stress(args.stress))
    else:
        run_benchmark(args.runs, args.label)

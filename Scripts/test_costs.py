import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(
        description="Measure test functions in separate, sequential Swift Testing processes.")
    parser.add_argument("--configuration", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--filter", default="")
    arguments = parser.parse_args()
    listing = subprocess.run(
        ["make", "--silent", "--no-print-directory", "test-list",
         f"TEST_CONFIGURATION={arguments.configuration}"],
        capture_output=True, text=True, check=True,
    )
    tests = [line.strip() for line in listing.stdout.splitlines()
             if re.fullmatch(r"\w+\.\w+/\S+", line.strip())
             and re.search(arguments.filter, line.strip())]
    if not tests:
        raise RuntimeError(f"No tests found in listing: {listing.stdout}")
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    logs = arguments.output.parent / f"{arguments.output.stem}-logs"
    logs.mkdir(exist_ok=True)
    results = []
    for index, name in enumerate(tests, 1):
        pattern = "^" + re.escape(name)
        started = time.perf_counter()
        run = subprocess.run(
            ["make", "--silent", "--no-print-directory", "test",
             f"TEST_CONFIGURATION={arguments.configuration}",
             "TEST_ARGS=--skip-build --no-parallel", f"TEST={pattern}"],
            capture_output=True, text=True,
        )
        elapsed = time.perf_counter() - started
        log = logs / f"{index:03d}.txt"
        output = run.stdout + run.stderr
        log.write_text(output)
        durations = re.findall(
            r"Test run with ([1-9]\d*) tests?.*passed after ([\d.]+) seconds", output)
        result = {
            "test": name, "wall_seconds": elapsed, "exit_code": run.returncode,
            "test_seconds": float(durations[-1][1]) if durations else None,
            "test_count": int(durations[-1][0]) if durations else 0, "log": str(log),
        }
        results.append(result)
        document = {
            "configuration": arguments.configuration, "pid": os.getpid(),
            "parallel": False, "results": results,
        }
        arguments.output.write_text(json.dumps(document, indent=2) + "\n")
        print(f"{index}/{len(tests)} {elapsed:.3f}s {name}", flush=True)
        if run.returncode or not durations or result["test_count"] != 1:
            raise RuntimeError(f"Test did not pass or run: {name}; inspect {log}")


if __name__ == "__main__":
    main()

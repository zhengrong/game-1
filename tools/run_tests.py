"""Run GUT and enforce 95% coverage in an isolated copy of the game."""
import dataclasses
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from gd_tools.coverage.plan_generator import read_plan_json
from gd_tools.coverage.reporter import generate_report, read_coverage_json


ROOT = Path(__file__).resolve().parents[1]
GENERATED = {".git", ".godot", ".gd-tools", ".venv-test", "coverage", "visual-reports", "__pycache__"}
TEST_ADDONS = {"gut", "gd-tools-coverage"}


def ignored(directory, names):
    excluded = set(names) & GENERATED
    if Path(directory) == ROOT / "addons":
        excluded |= set(names) & TEST_ADDONS
    return excluded


def main():
    executable = Path(sys.executable).parent / "gd-tools"
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot")
    if not godot:
        raise SystemExit("Set GODOT_BIN to the Godot 4.7.2 executable.")
    env = dict(os.environ, GODOT_BIN=godot, GD_TOOLS_NO_UPDATE_CHECK="1")
    work = ROOT / ".gd-tools"
    work.mkdir(exist_ok=True)
    reports = ROOT / "coverage"
    # Never leave an older successful report looking like this run's result.
    if reports.exists():
        shutil.rmtree(reports)
    reports.mkdir()
    with tempfile.TemporaryDirectory(prefix="test-project-", dir=work) as directory:
        stage = Path(directory)
        shutil.copytree(ROOT, stage, dirs_exist_ok=True, ignore=ignored)
        expected = {
            "res://" + str(path.relative_to(stage))
            for path in stage.rglob("*.gd")
            if "tests" not in path.relative_to(stage).parts
        }
        cache = work / "test-addons"
        for name in TEST_ADDONS:
            source = cache / name
            if not source.exists():
                source = ROOT / "addons" / name
            if source.exists():
                shutil.copytree(source, stage / "addons" / name)
        with (reports / "run.log").open("w") as log:
            def run(args):
                result = subprocess.run(args, cwd=stage, env=env,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        text=True, timeout=240)
                print(result.stdout, end="", flush=True)
                log.write(result.stdout)
                log.flush()
                if "SCRIPT ERROR:" in result.stdout or "SHADER ERROR:" in result.stdout:
                    print("Godot reported a script/shader error; rejecting this run even if GUT passed.", flush=True)
                    return result.returncode or 1
                return result.returncode

            code = run([str(executable), "init", "--non-interactive"])
            if code:
                return code
            gut_config = (stage / "addons/gut/plugin.cfg").read_text()
            if 'version="9.7.0"' not in gut_config:
                raise RuntimeError("This suite requires GUT 9.7.0.")
            for name in TEST_ADDONS:
                shutil.copytree(stage / "addons" / name, cache / name, dirs_exist_ok=True)
            code = run([godot, "--headless", "--path", str(stage),
                        "--editor", "--import", "--quit", "--audio-driver", "Dummy"])
            if code:
                return code
            code = run([str(executable), "test", "--coverage", "--min", "95", "--timeout", "120"])
        if (stage / "coverage").exists():
            shutil.copytree(stage / "coverage", reports, dirs_exist_ok=True)
        if (stage / ".gd-tools/results.xml").exists():
            shutil.copy2(stage / ".gd-tools/results.xml", reports / "results.xml")
        if code:
            return code
        plan = read_plan_json(str(reports / "plan.json"))
        actual = {file.path for file in plan.files}
        if actual != expected:
            raise RuntimeError(f"Coverage scope mismatch: missing={expected - actual}, extra={actual - expected}")
        result = generate_report(plan, read_coverage_json(reports / "coverage.json"),
                                 reports, format="html", min_threshold=0.95)
        summary = dataclasses.asdict(result.summary)
        summary["files"] = [dataclasses.asdict(file) for file in result.file_summaries]
        (reports / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(f"Verified {len(actual)} production scripts; line coverage {result.summary.line_rate:.2%}.")
        print(f"Report: {reports / 'index.html'}")
        return 0


if __name__ == "__main__":
    sys.exit(main())

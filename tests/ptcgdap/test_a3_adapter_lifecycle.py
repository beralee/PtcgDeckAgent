from pathlib import Path
import sys
import tempfile
import unittest

from scripts.ai.ptcgdap.a3_differential import GodotHeadlessEngineAdapter


class A3AdapterLifecycleTests(unittest.TestCase):
    def test_dispose_waits_for_bridge_cleanup_after_acknowledgement(self) -> None:
        # A bridge acknowledges disposal before its finally block releases the
        # engine. Killing it on acknowledgement strands the engine on Windows.
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "engine-released.txt"
            program = (
                "import json, pathlib, sys, time\n"
                "request = json.loads(sys.stdin.readline())\n"
                "assert request['method'] == 'dispose'\n"
                "print(json.dumps({'ok': True, 'result': None}), flush=True)\n"
                "time.sleep(0.2)\n"
                "pathlib.Path(sys.argv[1]).write_text('released')\n"
            )
            adapter = GodotHeadlessEngineAdapter(
                [sys.executable, "-c", program, str(marker)]
            )
            adapter._ensure_process()
            adapter.dispose()
            self.assertTrue(marker.is_file(), "bridge cleanup was interrupted")
            adapter.dispose()


if __name__ == "__main__":
    unittest.main()

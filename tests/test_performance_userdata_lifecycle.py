"""Real tiny child processes cover performance scratch lifetime, without Godot."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

from scripts.tools import run_performance_bench as bench


CHILD = r'''
import os, pathlib, sys, time
user = pathlib.Path(os.environ['APPDATA'])
app = user / 'Godot/app_userdata/PtcgDeckAgent'
(app / 'cards/images').mkdir(parents=True)
(app / 'cards/images/seed.bin').write_bytes(b'reproducible cache')
(app / 'cards/images/custom.bin').write_bytes(b'unique custom card')
(app / 'cards/images/wrapped.png').write_bytes(b'wrapped image')
(app / 'music/battle_bgm').mkdir(parents=True)
(app / 'music/battle_bgm/theme.mp3').write_bytes(b'builtin music')
(app / 'future-diagnostic.new').write_text('unknown evidence')
(app / 'match_records/match').mkdir(parents=True)
(app / 'match_records/match/detail.jsonl').write_text('unique replay')
(app / 'logs').mkdir()
(app / 'logs/battle_runtime.log').write_text('runtime evidence')
run = pathlib.Path(sys.argv[1])
(run / 'samples.json').write_text('sample evidence')
print('tiny child started', flush=True)
(run / 'child-ready').write_text(str(os.getpid()))
if sys.argv[2] == 'sleep': time.sleep(60)
sys.exit(7 if sys.argv[2] == 'fail' else 0)
'''


class PerformanceUserdataLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.run = self.root / 'run-01'
        self.run.mkdir()
        self.source_project = self.root / 'source-project'
        seed = self.source_project / 'data/bundled_user'
        (seed / 'cards/images').mkdir(parents=True)
        (seed / 'cards/images/seed.bin').write_bytes(b'reproducible cache')
        (seed / 'cards/images/custom.bin').write_bytes(b'original bundled version')
        (seed / 'cards/images/wrapped.png.bin').write_bytes(b'wrapped image')
        (self.source_project / 'assets/audio/bgm').mkdir(parents=True)
        (self.source_project / 'assets/audio/bgm/theme.mp3').write_bytes(b'builtin music')

    def invoke(self, mode='ok', **kwargs):
        return bench.invoke_process([sys.executable, '-c', CHILD, str(self.run), mode],
                                    self.root, self.run, source_project=self.source_project, **kwargs)

    def assert_released_with_evidence(self):
        self.assertFalse((self.run / 'user').exists())
        evidence = self.run / 'user-evidence/Godot/app_userdata/PtcgDeckAgent'
        self.assertEqual((evidence / 'match_records/match/detail.jsonl').read_text(), 'unique replay')
        self.assertEqual((evidence / 'logs/battle_runtime.log').read_text(), 'runtime evidence')
        self.assertEqual((self.run / 'samples.json').read_text(), 'sample evidence')
        self.assertIn('tiny child started', (self.run / 'console.log').read_text())
        self.assertFalse((evidence / 'cards/images/seed.bin').exists())
        self.assertFalse((evidence / 'cards/images/wrapped.png').exists())
        self.assertFalse((evidence / 'music/battle_bgm/theme.mp3').exists())
        self.assertEqual((evidence / 'cards/images/custom.bin').read_bytes(), b'unique custom card')
        self.assertEqual((evidence / 'future-diagnostic.new').read_text(), 'unknown evidence')

    def test_success_releases_cache_after_preserving_report_and_replay(self):
        self.assertEqual(self.invoke(timeout=10), [])
        self.assert_released_with_evidence()

    def test_nonzero_child_releases_cache_and_keeps_failure_evidence(self):
        self.assertEqual(self.invoke('fail', timeout=10), ['exit_code:7'])
        self.assert_released_with_evidence()

    def test_timeout_terminates_child_before_releasing_user(self):
        processes = []
        original = subprocess.Popen
        def capture(*args, **kwargs):
            process = original(*args, **kwargs)
            processes.append(process)
            return process
        with mock.patch.object(bench.subprocess, 'Popen', side_effect=capture):
            self.assertEqual(self.invoke('sleep', timeout=.5), ['process_timeout'])
        self.assertIsNotNone(processes[0].poll())
        self.assert_released_with_evidence()

    def test_interrupt_terminates_child_then_releases_user_and_propagates(self):
        original_wait = subprocess.Popen.wait
        processes = []
        interrupted = False
        def interrupt_wait(process, *args, **kwargs):
            nonlocal interrupted
            if not interrupted:
                processes.append(process)
                deadline = time.monotonic() + 5
                while not (self.run / 'child-ready').exists() and time.monotonic() < deadline:
                    time.sleep(.01)
                interrupted = True
                raise KeyboardInterrupt()
            return original_wait(process, *args, **kwargs)
        with mock.patch.object(subprocess.Popen, 'wait', interrupt_wait):
            with self.assertRaises(KeyboardInterrupt):
                self.invoke('sleep', timeout=10)
        self.assertIsNotNone(processes[0].poll())
        self.assert_released_with_evidence()

    def test_keep_user_data_is_an_explicit_opt_in(self):
        self.assertEqual(self.invoke(timeout=10, keep_user_data=True), [])
        self.assertTrue((self.run / 'user/Godot/app_userdata/PtcgDeckAgent/cards/images/seed.bin').is_file())
        self.assertFalse((self.run / 'user-evidence').exists())

    def test_existing_userdata_is_never_adopted_or_removed(self):
        (self.run / 'user').mkdir()
        sentinel = self.run / 'user/keep'
        sentinel.write_text('existing user data')
        with self.assertRaises(FileExistsError):
            self.invoke(timeout=10)
        self.assertEqual(sentinel.read_text(), 'existing user data')

    def test_cleanup_refuses_path_outside_this_run(self):
        outside = self.root / 'unowned'
        outside.mkdir()
        with self.assertRaises(ValueError):
            bench.release_userdata(self.run, outside)
        self.assertTrue(outside.exists())

    @unittest.skipUnless(os.name == 'nt', 'Windows junction boundary')
    def test_nested_junction_retains_user_and_does_not_touch_target(self):
        user, outside = self.run / 'user', self.root / 'outside'
        user.mkdir()
        outside.mkdir()
        (outside / 'keep').write_text('outside')
        escaped = str(outside).replace("'", "''")
        link = user / 'linked'
        result = subprocess.run(['powershell', '-NoProfile', '-Command',
            "New-Item -ItemType Junction -Path '" + str(link).replace("'", "''") + "' -Target '" + escaped + "' | Out-Null"],
            capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        try:
            with self.assertRaises(ValueError):
                bench.release_userdata(self.run, user)
            self.assertEqual((outside / 'keep').read_text(), 'outside')
            self.assertTrue(user.exists())
        finally:
            link.rmdir()


if __name__ == '__main__':
    unittest.main()

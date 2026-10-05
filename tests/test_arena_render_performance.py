import copy
import unittest
from tools.arena3d.compare_render_performance import compare
from tools.arena3d.run_render_performance import require_window


class ArenaPerformanceGate(unittest.TestCase):
    def fixture(self, mode='2d'):
        return {'kind':'arena_render_performance','mode':mode,'platform':{'display':'Windows','window':[390,844]},
                'fixture':'fixed','simulated_touch':True,'seconds_per_case':5,
                'cases':[{'case':label,'frame_gaps_ms':[16.667]*300,'updates':4} for label in ('idle','updates_and_attacks')]}

    def test_complete_pair_passes(self):
        self.assertTrue(compare(self.fixture(),self.fixture('3d'))['passed'])

    def test_requested_landscape_cannot_accept_portrait_twice(self):
        with self.assertRaises(RuntimeError): require_window(self.fixture(), '844x390')
        require_window(self.fixture(), '390x844')

    def test_instrumented_process_diagnostic_is_not_performance_acceptance(self):
        diagnostic = self.fixture('3d')
        diagnostic['kind'] = 'arena_process_diagnostic'
        with self.assertRaises(ValueError):
            compare(self.fixture('2d'), diagnostic)

    def test_missing_window_and_headless_and_different_device_fail(self):
        for mutation in (lambda r:r['cases'].pop(),lambda r:r['platform'].update(display='headless'),lambda r:r['platform'].update(window=[844,390])):
            candidate=self.fixture('3d')
            mutation(candidate)
            with self.assertRaises(ValueError): compare(self.fixture(),candidate)

    def test_tail_stalls_cannot_hide_behind_sixty_fps_median(self):
        candidate=self.fixture('3d')
        candidate['cases'][1]['frame_gaps_ms'][-10:]=[85]*10
        self.assertFalse(compare(self.fixture(),candidate)['passed'])

    def test_truncated_and_nonfinite_data_fail(self):
        for gaps in ([16.6]*101,[float('nan')]*300):
            candidate=self.fixture('3d')
            candidate['cases'][0]['frame_gaps_ms']=gaps
            with self.assertRaises(ValueError): compare(self.fixture(),candidate)


if __name__=='__main__': unittest.main()

import tempfile
import unittest
from pathlib import Path
import zipfile

from tools.inspect_2d_export_assets import inspect_members, read_export
from tests.ptcgdap.test_godot_export_canonicalizer import _build_pck


class Test2DExportAssets(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        asset = self.root / 'assets/arena3d/new-field/table.glb.import'
        asset.parent.mkdir(parents=True)
        asset.write_text('path="res://.godot/imported/table.glb-deadbeef.scn"\n')
        self.required = ['assets/ui/background.png']
        self.valid = {
            'assets/ui/background.png.import': b'path="res://.godot/imported/background.ctex"',
            '.godot/imported/background.ctex': b'texture',
        }

    def inspect(self, members):
        return inspect_members(members, self.root, self.required)

    def test_new_arena_source_is_rejected_without_a_fixed_file_list(self):
        report = self.inspect({**self.valid, 'assets/arena3d/future/new.glb': b'model'})
        self.assertFalse(report['passed'])
        self.assertEqual(report['forbidden_members'], ['assets/arena3d/future/new.glb'])

    def test_orphaned_imported_arena_model_is_rejected(self):
        report = self.inspect({**self.valid, '.godot/imported/table.glb-deadbeef.scn': b'model'})
        self.assertFalse(report['passed'])
        self.assertEqual(len(report['forbidden_members']), 1)

    def test_shared_2d_resources_and_small_helpers_are_retained(self):
        report = self.inspect({**self.valid, 'scenes/arena3d/ArenaPlatform.gdc': b'script'})
        self.assertTrue(report['passed'])

    def test_import_descriptor_without_texture_fails(self):
        report = self.inspect({'assets/ui/background.png.import': self.valid['assets/ui/background.png.import']})
        self.assertFalse(report['passed'])
        self.assertEqual(report['missing_resources'], self.required)

    def test_missing_resource_fails(self):
        self.assertFalse(self.inspect({})['passed'])

    def test_portable_requires_preview_and_still_rejects_desktop_media(self):
        preview = 'assets/arena3d/previews/grove.png'
        accepted = {**self.valid, preview: b'preview',
                    'assets/arena3d/portable/manifest.json': b'{}',
                    'assets/arena3d/portable/grove_table.glb': b'model',
                    'assets/arena3d/portable/reward_cradle.glb': b'model'}
        self.assertTrue(inspect_members(accepted, self.root, self.required, 'portable')['passed'])
        self.assertFalse(inspect_members(self.valid, self.root, self.required, 'portable')['passed'])
        self.assertFalse(inspect_members({**accepted, '.godot/imported/table.glb-deadbeef.scn': b'model'}, self.root, self.required, 'portable')['passed'])

    def test_portable_cannot_omit_a_desktop_character_even_if_manifest_omits_it(self):
        source = self.root / 'assets/arena3d/pokemon/charizard.glb'
        source.parent.mkdir(parents=True)
        source.write_bytes(b'desktop model')
        report = inspect_members(self.valid, self.root, self.required, 'portable')
        self.assertIn('assets/arena3d/portable/pokemon/charizard.glb', report['missing_resources'])

    def test_all_exported_texture_variants_must_exist(self):
        members = dict(self.valid)
        members['assets/ui/background.png.import'] += b'\npath.etc2="res://.godot/imported/background.etc2.ctex"'
        self.assertFalse(self.inspect(members)['passed'])

    def test_apk_assets_prefix_and_import_payload_are_read(self):
        archive = self.root / 'game.apk'
        with zipfile.ZipFile(archive, 'w') as z:
            for name, data in self.valid.items():
                z.writestr('assets/' + name, data)
            z.writestr('AndroidManifest.xml', b'manifest')
        self.assertTrue(self.inspect(read_export(archive))['passed'])

    def test_real_pck_directory_and_remaps_are_read(self):
        archive = self.root / 'game.pck'
        archive.write_bytes(_build_pck(self.valid, list(self.valid)))
        self.assertTrue(self.inspect(read_export(archive))['passed'])


if __name__ == '__main__':
    unittest.main()

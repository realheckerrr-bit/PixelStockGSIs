import importlib.util
import pathlib
import unittest


SCRIPT = pathlib.Path(__file__).parents[1] / "scripts" / "resolve_official_pixel_image.py"
SPEC = importlib.util.spec_from_file_location("resolver", SCRIPT)
RESOLVER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(RESOLVER)


class OfficialPageParserTest(unittest.TestCase):
    def test_resolves_device_row_and_checksum(self):
        page = """
        <table><tr id="bluejay"><td>Pixel 6a</td><td>
        bluejay_beta-build-factory-abcd1234.zip
        <code>9010a8fa5630f49db955487cecb3e58a2939a69fdfb1a6097c2510611ad68618</code>
        </td></tr></table>
        <a href="https://dl.google.com/developers/android/cinnamonbun/images/factory/bluejay_beta-build-factory-abcd1234.zip">download</a>
        """
        url, checksum = RESOLVER.parse_image_page(page, "bluejay")
        self.assertTrue(url.startswith("https://dl.google.com/"))
        self.assertEqual(checksum, "9010a8fa5630f49db955487cecb3e58a2939a69fdfb1a6097c2510611ad68618")

    def test_rejects_unknown_device(self):
        with self.assertRaises(ValueError):
            RESOLVER.parse_image_page("<table></table>", "unknown")


if __name__ == "__main__":
    unittest.main()

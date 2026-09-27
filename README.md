# PixelStockGSI's

PixelStockGSI's is a GitHub Actions tool that downloads an official Google
Pixel factory image or full OTA package, extracts its `system.img`, applies a
small Project Treble/GSI compatibility patch, rebuilds the system image, and
publishes release assets.

The GitHub repository uses the slug `PixelStockGSIs` because apostrophes are
not a useful repository-name character. The project and release branding is
`PixelStockGSI's`.

## What this produces

Each successful workflow run publishes:

- `*.img.xz`: sparse system image for normal fastboot/TWRP-style GSI flashing;
- `*.img.gz`: raw system image compressed in the format commonly accepted by
  DSU sideloaders;
- `SHA256SUMS.txt`;
- complete build information embedded in the GitHub Release notes, including
  the exact Google URL, source SHA-256, Pixel build properties, and GitHub
  run/commit;
- `compatibility-report.txt`.

The release tag follows the same style as the companion project:
`vYYYY.MM.DD-HHMMSS-RUN_ID`.

## Run it on GitHub

1. Create or open the `PixelStockGSIs` repository.
2. Open **Actions → Build PixelStockGSI** and choose **Run workflow**.
3. Either paste a direct HTTPS URL and its SHA-256, or enter an official
   Android download page plus a Pixel codename such as `bluejay`:
   - factory images: <https://developers.google.com/android/images>
   - full OTA images: <https://developers.google.com/android/ota>
   - Android 17 QPR2 example page: <https://developer.android.com/about/versions/17/qpr2/download>
4. When using page resolution, enter the row codename (`bluejay`, `panther`,
   `shiba`, etc.). The resolver extracts only the matching Google URL and the
   SHA-256 printed in that official row.
5. Choose `ext4` for the broadest compatibility, or `erofs` for a smaller
   read-only image.
6. Download the assets from the created GitHub Release and verify
   `SHA256SUMS.txt` before using them.

The downloader accepts only known Google distribution hosts (`dl.google.com`,
`storage.googleapis.com`, `android.googleapis.com`, and
`ota.googlezip.net`). A random mirror, Google Drive link, or arbitrary URL is
rejected so the provenance claim remains meaningful.

## Important compatibility limits

This project makes a Pixel `system.img` into a Treble-shaped GSI; it cannot
make one Android image boot literally every phone. The target still supplies
the matching vendor implementation, kernel/modules, DTB, boot/vendor_boot,
vbmeta policy, partition layout, and recovery/flash method. The bootloader
must be unlockable and the device must support Project Treble/GSI installation
(normally Android 9+ with an unlocked bootloader).

The workflow fails on unsupported CPU ABI metadata and refuses to publish a
release when the source does not look like an Android system image. It emits
warnings for device-specific dependencies instead of pretending they are
universal. A Pixel system image may still need a compatible vendor/product/
system_ext combination; those partitions are not silently copied into the
GSI because doing so can create a misleading, unbootable cross-device image.

This is not an OEM-signed Google image, does not contain Google's signing keys,
does not disable AVB on the target, and does not include a universal kernel.
Use only on hardware you own and follow the device-specific GSI procedure.

## Local Linux/WSL usage

The workflow is the supported path, but the same script can run on Debian or
Ubuntu with the packages listed in `.github/workflows/build_pixel_stock_gsi.yml`:

```bash
bash scripts/install_dependencies.sh
bash scripts/build_pixel_stock_gsi.sh \
  "https://dl.google.com/dl/android/aosp/EXAMPLE-factory.zip" \
  "PixelStockGSI" \
  "ext4" \
  "$(pwd)/workspace" \
  "<sha256-from-google>"
```

The local command is intentionally explicit. It never discovers or downloads
an image from an unofficial mirror.

## Google licensing

Google's Pixel images remain subject to the terms shown on Google's download
pages and the license included with each package. PixelStockGSI's does not
redistribute Google's stock package; it downloads the URL supplied at build
time and publishes the resulting user-generated artifact. Check the license
and your local laws before using or sharing any output.

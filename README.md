# PixelStockGSI's

The workflow also normalizes missing generic GSI root mount points and
system-as-root entry-point symlinks before rebuilding the image. The release
compatibility report records that change and its scope.

PixelStockGSI's is a GitHub Actions tool that downloads an official Google
Pixel factory/OTA image or an official Google GSI ZIP, extracts its
`system.img`, applies a small Project Treble/GSI compatibility patch, rebuilds
the system image, and publishes release assets.

The GitHub repository uses the slug `PixelStockGSIs` because apostrophes are
not a useful repository-name character. The project and release branding is
`PixelStockGSI's`.

## What this produces

Each successful workflow run publishes:

- `*.img.xz`: sparse system image for normal fastboot/TWRP-style GSI flashing;
- `*.img.gz`: raw system image compressed in the format commonly accepted by
  DSU sideloaders;
- `SHA256SUMS.txt`;
- a source-mode record identifying whether the build used a Pixel stock image
  or Google's official GSI image as its base;
- complete build information embedded in the GitHub Release notes, including
  the exact Google URL, source SHA-256, downloaded-device hint, the original
  unmodified system properties, and GitHub run/commit;
- the complete compatibility preflight report embedded in the GitHub Release
  notes and attached as `compatibility-report.txt`.

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
   SHA-256 printed in that official row. Use a Google page for the matching
   Android release family; the current generic factory page may no longer list
   older Pixel codenames. If a row is missing, the workflow error lists the
   row IDs that the selected page actually contains.
5. Leave **Source mode** as `pixel_stock` for the requested Pixel-derived
   build. For the strongest cross-device GSI baseline, choose `official_gsi`
   and provide the direct Google GSI ZIP URL plus its SHA-256; that mode uses
   Google's already-generic GSI layout instead of converting a Pixel partition
   into one.
6. Choose `ext4` for the broadest compatibility, or `erofs` for a smaller
   read-only image.
7. Leave **Publish release** enabled for the normal release workflow. Disable
   it for a validation-only build; the image is built and checked on GitHub
   but no public Release or workflow artifact is created.
8. Download the assets from the created GitHub Release and verify
   `SHA256SUMS.txt` before using them.

### Windows quick launcher

Install and authenticate the [GitHub CLI](https://cli.github.com/), then run
the PowerShell dispatcher from a cloned copy of this repository:

```powershell
.\scripts\Invoke-PixelStockGSI.ps1 `
  -DeviceCodename bluejay `
  -OutputName "PixelStockGSI" `
  -Wait
```

For Pixel official-page resolution, omit `-GoogleUrl` and `-Sha256` and
provide a Pixel codename instead, for example `-DeviceCodename bluejay`.
For the official GSI base, pass `-SourceMode official_gsi` together with a
direct Google GSI ZIP URL and its `-Sha256`. Use `-PublishRelease $false` for
a validation-only run. When a direct URL is used without a codename, the
release derives a clearly labelled device hint from the official package
filename when possible; official GSI packages are recorded as
`not-device-specific`. If an Android device is connected through ADB, add
`-TargetAdbSerial <serial>` to capture a small sanitized target-property
profile; the release compatibility report will then check that target's
Treble flag, ABI, Android SDK, and vendor-interface markers. If ADB is not
available, save `adb shell getprop` output (or `key=value` lines) and pass
`-TargetPropertiesPath .\target-getprop.txt` instead; unsupported properties
are discarded before the profile is sent to GitHub.
When a target profile is supplied and `-TargetModel` is left at its default,
the workflow derives the target hint from `ro.product.device`.

The downloader accepts only known Google distribution hosts (`dl.google.com`,
`storage.googleapis.com`, `android.googleapis.com`, and
`ota.googlezip.net`). A random mirror, Google Drive link, or arbitrary URL is
rejected so the provenance claim remains meaningful.

## Important compatibility limits

This project makes a Pixel `system.img` into a best-effort Treble/GSI-shaped
system image; it is not an AOSP-built universal GSI and cannot make one
Android image boot literally every phone. The target still supplies
the matching vendor implementation, kernel/modules, DTB, boot/vendor_boot,
vbmeta policy, partition layout, and recovery/flash method. The bootloader
must be unlockable and the device must support Project Treble/GSI installation
(normally Android 9+ with an unlocked bootloader).

Read the release body's **Compatibility preflight** section before flashing.
In particular, `System layout` and `Framework VINTF metadata` expose whether
the extracted Pixel system has the layout and metadata expected by a target;
warnings are not a universal boot guarantee.

The workflow fails on unsupported CPU ABI metadata and refuses to publish a
release when the source does not look like an Android system image. It emits
warnings for device-specific dependencies instead of pretending they are
universal. A Pixel system image may still need a compatible vendor/product/
system_ext combination; those partitions are not silently copied into the
GSI because doing so can create a misleading, unbootable cross-device image.

The release's source-provenance section is captured before patching. It records
the device selected on Google's download page (when supplied), the downloaded
package filename, and the relevant original ro.product.* and ro.build.*
properties. The rebuilt system partition then replaces framework-facing
product identity markers with generic PixelStockGSI values, while the release
provenance retains the original source identity.

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

Google's Pixel and GSI images remain subject to the terms shown on Google's
download pages and the license included with each package. PixelStockGSI's
does not bundle a stock package in the repository; it downloads the URL
supplied at build time and publishes the resulting user-generated artifact.
The `official_gsi` mode may carry additional Google GSI terms that restrict
modification or redistribution, so check the applicable license before using
or sharing any output.

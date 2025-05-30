# Release

To create a new release, follow these steps:

1. Update the version in the `VERSION` file.
1. Generate all ISOs by running `sudo make build -- --no-usb` (remember to rename the ISOs to avoid overwriting the previous ones).
1. Upload the ISO files to `archive.org` by running:

   ```bash
   make upload
   ```

   This target builds a Docker container that uses the `upload.py` script to upload all `.iso` files from the `dist/` directory to archive.org with preconfigured metadata. Ensure you have an `ia.ini` file with your archive.org credentials in the repository root (excluded from version control).

1. Run `make checksums` to generate the SHA256 checksums.
1. Create a new release on GitHub:
   - Tag the release with the version number (`v<version>`).
   - Add a title `v<version>`
   - Add the `archive.org` links to the ISO files in the description.
   - Attach the SHA256 checksums file.
   - Publish the release.
   - Clean up the `dist` directory by running `sudo make clean-dist`.

`TODO: Automate the release process further.`

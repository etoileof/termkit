# termkit

A personal terminal tool, packaged for Windows.

## Install (Windows 10/11, x64)

1. Download the `.zip` from the [latest release](../../releases/latest).
2. Extract it and double-click `Install.cmd`.
3. Paste your two API keys when asked. Press Enter to skip either one.
4. Open a new terminal window in your project folder and start it as shown at the end of the install.

No admin rights needed. Run `Install.cmd` again to update or to change keys. `Uninstall.cmd` removes it.

## Building

GitHub Actions builds a new release whenever `payload.tar.gz` changes. To edit it: `sh pack.sh unpack`, change files in `payload/`, run `sh pack.sh`, then commit and push.

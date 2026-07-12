A GUI installer is included for installing surface-dots.

Installer [source code](./.source_codes/installer_src) and [documentation](./.source_codes/installer_src/installer_readme.md)

> [!IMPORTANT]
>
> - The installer does **not** install dependencies. Install any required packages through your distribution’s package manager before running it.
> - Some files from `.config` are intentionally skipped by the installer. If you need anything not included in the automated install, please manually copy the files from git clone.
> - The installer has only been tested on Arch Linux with the glibc versions used by Arch. Compatibility with other distributions is unknown. If you test it on another distribution, feel free to report whether it works or fails.
> - If the installer fails to launch, you may need the `WebKitGTK runtime libraries`. If it still crashes on launch try:
>   `WEBKIT_DISABLE_COMPOSITING_MODE=1 WEBKIT_DISABLE_GPU_PROCESS=1 ./surface-dots-installer`
> - You **must** have a polkit authentication agent installed and running before you run the installer to prompt you for your sudo password

##### Installation Steps

1. Clone the repository
2. Make the precompiled installer executable
3. Launch the installer

```bash
git clone https://github.com/snes19xx/surface-dots
cd surface-dots
chmod +x surface-dots-installer
./surface-dots-installer
```

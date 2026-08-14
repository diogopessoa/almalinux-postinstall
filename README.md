# AlmaLinux Postinstall

<p align="center">
  <img src="https://raw.githubusercontent.com/diogopessoa/almalinux-postinstall/main/files/screenshot_almalinux.png" alt="screenshot of AlmaLinux.png" width="100%" style="border-radius: 8px;">
</p>

A personal post-installation script for **[AlmaLinux 10 Atomic Workstation](https://github.com/AlmaLinux/atomic-workstation)** that automates the setup of a practical desktop environment.

## What the script does

* Installs and configures Homebrew
* Installs Zsh, Starship, and Zsh plugins
* Sets Homebrew Zsh as the default shell
* Configures Homebrew for Bash
* Configures automatic Homebrew updates
* Configures automatic Distrobox container updates
* Installs Office fonts
* Installs the Hatter Icons theme without losing the original style
* Installs Bootc Manager
* Installs extras Flatpak applications
* Disables `NetworkManager-wait-online.service`to speed up system startup

## Download and Install

Run the following commands in the terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/diogopessoa/almalinux-postinstall/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

The script must be run as a **regular user**, not as root. `sudo` is requested automatically when administrative privileges are required.

## File Destination Tree

```text
$HOME/
├── .zshrc
├── .local/
│   ├── share/
│   │   ├── fonts/
│   │   │   └── office_fonts/
│   │   └── icons/
│   │       └── Hatter/
│
└── ...

/home/linuxbrew/.linuxbrew/
└── bin/
    ├── brew
    └── zsh

/etc/
├── shells
└── profile.d/
    └── homebrew.sh
```

The script also installs the configured Flatpak applications system-wide and creates the Homebrew/Distrobox update services through their respective installation scripts.

## References & Links

* [AlmaLinux GitHub](https://github.com/AlmaLinux)
* [Homebrew](https://brew.sh)
* [Distrobox](https://distrobox.it)
* [Hatter Icons Theme](https://github.com/Mibea/Hatter)
* [Bootc](https://bootc.dev/)


## License

This project is licensed under the [MIT License](https://www.google.com/search?q=LICENSE).

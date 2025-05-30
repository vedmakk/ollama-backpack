# 🎒 Ollama Backpack

A plug-and-play Debian Live ISO with Ollama preinstalled — bootable from USB, air-gapped by design, and ready to run large language models offline.

## 🎯 What Is This?

**Ollama Backpack** is a self-contained, bootable Debian Live ISO preloaded with Ollama and open-source language models.

- No internet required.
- No installation needed.
- Just boot and run.

It's ideal for:

- Exploring LLMs without touching your main OS
- Offline AI development environments
- Educational or lab use
- Developers who want a clean, minimal LLM sandbox

Whether you're on a train, in the mountains, or just dodging flaky Wi-Fi, your models go where you go.

## 📦 What's Inside?

- 🧠 Ollama – Preinstalled and ready to run
- 🗂️ Preloaded models – Choose your own or bundle them into the ISO
- 🖥️ XFCE Desktop – Lightweight and fast
- 📴 Air-gapped by default – Network drivers are blacklisted for maximum isolation (but easily reversible if you want)

This isn't a secure communication platform or privacy tool — just a portable LLM lab you can boot from anywhere.

## 🚀 Quick Start

Head over to the [Releases](https://github.com/vedmakk/ollama-backpack/releases) page. There you'll find:

- The latest ISO files hosted on `archive.org`.
- A `sha256sums.txt` file to verify the download.

### Step-by-step:

1. Download the ISO(s) you want.
1. Download the SHA256 checksum file into the same directory.
1. Verify your ISO:

```bash
sha256sum -c sha256sums.txt
```

Then burn it to your USB stick like it's 2009:

```bash
sudo dd if=/path/to/iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/path/to/iso` and `/dev/sdX` with your actual values. ⚠️ Triple-check the device or you'll be reformatting your cat pictures.

_Or, build your own ISO. Instructions below._

## 🛠️ Build your own ISO

Prefer to customize or verify everything yourself? You can build the ISO locally using the provided scripts.

### Requirements

- Debian-based host system (e.g., Debian, Ubuntu)
- Root privileges
- [Docker](https://docs.docker.com/get-docker/) installed
- `make` installed (`sudo apt-get install make`)
- Internet connection (for building only)
- Pre-downloaded Ollama models

### Build Instructions

Clone the repository and run the setup script:

```bash
make setup
```

Then build the ISO:

```bash
sudo make build

# or

sudo make build -- [OPTIONS]
```

Use `--help` for all available options.

### Example

```bash
sudo make build -- \
  --models-path ~/.ollama/models \
  --no-usb
```

_Note: The `--` is required before any options._

### Output

The generated ISO image containing all tools and configurations:
`./dist/ollama-backpack-<version>-<arch>.iso`

### 🧩 Ollama Models

To bundle models into your custom ISO:

1. Install [Ollama](https://ollama.com) on your host.
1. Run `ollama pull <model>` for each model you want.
1. Point the build script at the model directory:

```bash
sudo make build -- --models-path /home/user/.ollama/models
```

Models will be copied into the ISO.

> [!NOTE]
> The default path for Ollama to save pulled models when you installed it using the official install script for linux is `/usr/share/ollama/.ollama/models`.
> If you installed Ollama using a different method, you need to specify the correct path. Typically `~/.ollama/models`.

### 🔧 Customizing the Live System

Customize the live system by editing the `build.sh` script file.

You can tweak:

- Installed packages in `config/package-lists/custom.list.chroot`
- Kernel module blacklist in `config/includes.chroot/etc/modprobe.d/blacklist-network.conf`
- Desktop README (--readme path)

You can even disable the network lockdown entirely — just modify the config before build.

## 🤝 Contributing

Ideas, improvements, PRs — all welcome. If you want to help make this ISO better, faster, or more flexible, open an issue or submit a pull request.

## 📜 License

MIT — use freely, modify openly, and share widely.
See the [LICENSE](LICENSE) file for details.

# Inês' Dotfiles
This repository contains the config files I use on macOS, which I manage using Chezmoi. This repository also contains a one line installation script so that I can quickly setup new machines or reconfigure mine after a factory reset. The script will install the apps I use on my system, restore my dotfiles and set some sensible macOS defaults like autohide dock using defaults commands so I don't have to cycle through what feels like endless menus.

## Installation
**Warning:** This one line installation is meant for my personal use. It installs the apps I use and includes integration with 1Password where I store secrets like my SSH and Git Signing keys. The script assumes my vault structure so most likely this script won't work for you, however, if you're still interested in trying out some of these dotfiles, I recommend forking the repository, reviewing the code, and removing any parts you don’t need or want. This setup is designed specifically for my macOS workflow and may not be suitable for everyone.

```shell
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/inesiscosta/dotfiles/main/setup.sh)"
```

<details>
  <summary><h3>Adapting for your personal use.</h3></summary>
<p>Let's start with Homebrew. This configuration assumes you will use it, the installation script installs it for you and it installs both 1Password and Chezmoi through it.</p>

<p>Chezmoi, as referenced before, is the tool currently being used to manage these dotfiles. If you don't plan on using brew, <a href="https://www.chezmoi.io/install/#__tabbed_1_1">this page</a> has a bunch of alternative ways to install it on macOS, Linux, Windows, and some other OS's using a variety of different package managers.</p>

<p>I won't go into details about how to adapt this config for other dotfile managers other than Chezmoi as that would be too long. However, rest assured that apart from Chezmoi-specific syntax in <code>.tmpl</code> files, everything else, including scripts, should work with your dotfile manager of choice. My personal favorite and the one I was using before this was GNU Stow, which isn't specifically designed for dotfiles but rather a symlink farmer, but it worked great for me.</p>

<p>I migrated away from it because I couldn't manage to figure out a way to keep secrets private when commiting changes to GitHub. This won't be a problem if you don't want to "store" your keys on GitHub, but ideally, I would like to migrate my keys when I restore my computer, and having them on GitHub allows for the simple one-line installation I managed to achieve with Chezmoi. A quick web search will tell you all about other dotfile managers and their pros and cons. For your convinience however, I found this <a href="https://dotfiles.github.io/">website</a>.</p>

<p>If you do decide stick with Chezmoi, you aren't forced to use 1Password. Chezmoi offers integrations with all major password managers, a list of supported password managers can be found on their official website <a href="https://www.chezmoi.io/user-guide/password-managers/">here</a>. After choosing your password manager, you can look at the official documentation on the Chezmoi's website above and change the <code>.tmpl</code> files with the code your chosen password manager uses with Chezmoi to fill in your sensitive information. Again this is all clearly explained on Chezmoi's website.</p>

<p>About substituting Homebrew, you would need to remove the cron job I added on line 24 of <code>home/run_once_setup.sh.tmpl</code>, which only works on macOS anyway so also remove this if you are using Brew on another OS. This cron job runs <code>brew update</code> and <code> brew upgrade</code> automatically every 14 days. If you opt out of using Homebrew you will also need to change lines 25 onwards with whatever syntax your package manager uses for installing applications. Brew allows installing from a list in a Brewfile using <code>brew bundle</code>. If your package manager allows for similar behavior, I would highly encourage it. However, you can always hardcode your list of things to install in there. Using Brew, that would look like this: <code>brew install &lt;app name&gt; &lt;other app name&gt; &lt;other other app name&gt;</code>, etc.</p>

<p>You should also change the <code>backup.sh</code> script to either just not create a Brewfile altogether or to create the equivalent version of a Brewfile for your package manager basically a list of the apps you installed with said package manager. On the subject of backups, if you are not on macOS, you should remove the part where I force an iCloud sync after zipping my Dev folder and instead add logic to save your important files elsewhere be that an external drive or cloud service, you can add the logic to back up other folders in there too. I only chose to backup my Dev folder as my Desktop and Documents folders are already iCloud-synced, and I do not care for what I have in my Downloads folder.</p>

<p>If you do decide to stick with Brew, consider changing my Brewfile to include the apps and formulae you care about. If you are not using macOS, remove the <code>mas</code> formula which stands for mac app store and remove the remaining <code>mas</code> apps.</p>

<p>This also goes without saying but in case you just skimmed through the dotfiles if you are not on macOS remove the section in <code>home/run_once_setup.sh.tmpl</code> called macOS config there should be a helpful comment making it easy to spot. It won't run on other OS' thanks to Chezmoi but it's definitely not necessary and its huge because macOS comes with some very questionable defaults I prefer to change.</p>

<p>Lastly, you can and should, edit the actual dotfiles to your liking. So far this text has mostly been about the installation scripts but you should edit the config files for Alacritty, nvim, tmux, etc. to your liking or remove them all together if you don't use them and add the configs for your own apps and shell configuration. I personally use zsh (and I have my own prompt based on oh-my-zsh's Robby Russell theme!).</p>
<p>Enjoy!</p>
  
</details>

## Features & Tools Managed

This repository includes configurations and automation for the following:

### 🔑 Security & Credentials
- SSH keys stored in **1Password**
- GPG private and public keys and trust stored in **1Password**
- Git signing and commit verification setup

### ⚙️ Development Environment
- **Git** (`home/dot_gitconfig`)
- **zsh** (`home/dot_zshrc`)
- **Alacritty** (`home/dot_config/alacritty`)
- **Neovim** (`home/dot_config/nvim`)
- **Tmux** (`home/dot_config/tmux/tmux.conf`)

### 💻 System & Package Management
- **Homebrew** for package management
- **Brewfile** for automated app installation via `brew bundle`
- **Chezmoi** for dotfile management and synchronization
- Backup and restore functionality saving important data to iCloud or 1Password

### 📦 Installed Packages
#### Homebrew Packages
<pre>
bat chezmoi clang-format coreutils fzf gcc gh git gnupg lizard-analyzer lporg make mas neovim node openjdk rust telnet tmux tree zoxide zsh-autosuggestions
</pre>

#### Homebrew Casks
<pre>
1password 1password-cli alacritty alt-tab google-chrome iina keka microsoft-auto-update microsoft-excel microsoft-powerpoint microsoft-word raycast rectangle spotify termius visual-studio-code whatsapp
</pre>

#### Mac App Store Apps
<pre>
Amphetamine (937984704) Goodnotes (1444383602) Spark Desktop (6445813049) Xcode (497799835)
</pre>

## Roadmap
- Finish adding some macOS defaults (about 15 missing, mostly related to finder and displays).
- Backup raycast settings and quicklinks in backup.sh and restore them in run_once_setup.sh.tmpl.
- Setup fzf and bat.
- Tweak nvim and tmux configs.
- Use chezmoi tmpl's to make the dotfiles cross platform with support for both macOS and Linux.

## Huge thanks to...
- [Mathias Bynens](https://mathiasbynens.be/) and [Kevin Suttle](https://kevinsuttle.com/) for their macOS defaults [repositories](https://github.com/kevinSuttle/MacOS-Defaults).


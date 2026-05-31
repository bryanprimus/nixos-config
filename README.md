# Initiate MacBook after fresh install

## Download xcode developer tools

Open terminal and run this anywhere
```
git init
```

It will detect that we don't have xcode developer tools, after that follow the daemon gui installer

## System settings

### Trackpad natural scrolling

```
Settings > Scroll & Zoom > (Disable) Natural scrolling
```

### Keyboard repeat and delay rate

```bash
Settings > Keyboard > (Set both to max) Key repeat rate and Delay until repeat
```

### Dock

```bash
Settings > Desktop & Dock > (Enable) Automatically hide and show the dock 
```

Reset dock content

```
defaults write com.apple.dock persistent-apps -array && defaults write com.apple.dock persistent-others -array && defaults write com.apple.dock show-recents -bool false && killall Dock
```

## Setup Nix

First go to [nix-darwin](https://github.com/nix-darwin/nix-darwin) repo

Install nix using lix installer just like in the [prerequisites](https://github.com/nix-darwin/nix-darwin#prerequisites)

> Somehow the first install always fail, and it will succeed on the second one

Next follow the [getting started](https://github.com/nix-darwin/nix-darwin#getting-started) section using flakes.

Follow them all manually until we have `darwin-rebuild` cli installed.

After that go to [bryanprimus/nixos-config](https://github.com/bryanprimus/nixos-config), copy the flake.nix content manually and paste to our newly setup nix-darwin config locally.

Install rosetta next

```bash
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
```

Lastly run
```
sudo darwin-rebuild switch
```

## Setup git

We need to set ssh keys into our local, or you can generate from the start if you want to by following this [guide](https://bryanprim.us/blogs/using-ssh-to-connect-local-git-to-remote-repositories)

### Pre-stored ssh keys

```bash
vi ~/.ssh/id_ed25519.pub

# paste public keys here
```

and then

```bash
vi ~/.ssh/id_ed25519

# paste correctly formatted private key here
```

> Allow permission to that private key

```
chmod 600 ~/.ssh/id_ed25519
```

Check the connection

```
ssh -T git@github.com
```

It should say something like

```txt
Hi <your-username>! You've successfully authenticated...
```








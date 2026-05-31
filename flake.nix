{
  # Flake Description
  description = "Declarative macOS config for Bryan's MacBook Pro (aarch64-darwin) using nix-darwin, nix-homebrew, and home-manager; locks Homebrew taps via flake.";

  # Flake Inputs - External Dependencies
  # Think of these as the "ingredients" for your system configuration
  inputs = {
    # nixpkgs: The main package repository (like npm, but for everything)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin: The framework that lets you configure macOS declaratively
    # This is what makes "darwin-rebuild" work
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # nix-homebrew: Manages Homebrew declaratively (no more manual brew installs!)
    nix-homebrew.url = "github:zhaofengli/nix-homebrew/main";

    # Homebrew tap sources - These let you lock Homebrew packages to specific versions
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    # home-manager: Manages your user-level configs (dotfiles, shell setup, etc.)
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Flake Outputs - Your System Configuration
  outputs =
    {
      self,
      nix-darwin,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      home-manager,
      ...
    }:
    let
      # Your username - change this if you have a different user
      user = "bryan";

      # Main System Configuration
      configuration =
        {
          pkgs,
          lib,
          config,
          ...
        }:
        {
          # Set up your user account
          system.primaryUser = user;
          users.users.${user}.home = "/Users/${user}";

          # System Packages - CLI tools installed system-wide
          # Search for more packages at: https://search.nixos.org/packages
          environment.systemPackages = with pkgs; [
            # Code Editor
            vim

            # Formatter
            nixfmt

            # JS Toolkit
            bun

            # nix language server
            nil
            nixd

            # Container tools (Nix-managed)
            docker
            docker-compose
            colima

            # ai tools
            kiro-cli
          ];

          #--------------------------------------------------------------------
          # Nix Settings - Enables flakes and the new nix commands
          #--------------------------------------------------------------------
          nix.settings.experimental-features = "nix-command flakes";

          # Automatic GC: keep last 7 days of generations
          nix.gc = {
            automatic = true;
            interval = { Hour = 3; Minute = 15; };
            options = "--delete-older-than 7d";
          };

          # Allow only specific unfree packages (e.g., kiro-cli)
          nixpkgs.config.allowUnfreePredicate =
            pkg:
            builtins.elem (lib.getName pkg) [
              "kiro-cli"
            ];

          #--------------------------------------------------------------------
          # System Metadata - Don't touch these unless you know what you're doing
          #--------------------------------------------------------------------
          # Uncomment if you want to use fish shell instead of zsh
          # programs.fish.enable = true;

          # Tracks which git commit built your system (for rollbacks)
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Compatibility version - read changelog before changing
          # Run: darwin-rebuild changelog
          system.stateVersion = 6;

          # Your Mac's architecture (Apple Silicon)
          nixpkgs.hostPlatform = "aarch64-darwin";

          #--------------------------------------------------------------------
          # Homebrew - GUI Apps & macOS-specific tools
          # Use this for apps that don't work well with Nix or need macOS integration
          #--------------------------------------------------------------------
          homebrew = {
            enable = true;

            # GUI applications (installed via Homebrew Cask)
            casks = [
              # utils
              "rectangle"
              "cleanshot"
              # "outerbase-studio" # not always needed

              # browsers
              "arc"
              "chatgpt-atlas"

              # messagings
              "whatsapp"
              "discord"
              # "telegram" # not always needed

              # terminal
              "iterm2"

              # ai tools
              "zed"
              "grok-build"
              "codex-app"

              # productivity
              "linear"
            ];

            # CLI applications
            brews = [
              # JS Toolkit
              "node"
              "opencode"

              # easy postgres
              # "libpq" # not always needed
            ];

            # "zap" = uninstall anything not listed above
            # This keeps your system clean but be careful!
            onActivation = {
              cleanup = "zap";
            };
          };
        };
    in
    {
      #========================================================================
      # Host Configuration - This is your actual computer
      #
      # 🚀 Quick Commands:
      # Apply changes:  darwin-rebuild switch --flake .#Bryans-MacBook-Pro
      # Test first:     darwin-rebuild build --flake .#Bryans-MacBook-Pro
      # Check config:   darwin-rebuild check --flake .#Bryans-MacBook-Pro
      # See history:    darwin-rebuild --list-generations
      #
      # Pro tip: Run "check" before "switch" to catch errors without changing your system!
      #========================================================================
      darwinConfigurations."Bryans-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [
          # Your base system config from above
          configuration

          #--------------------------------------------------------------------
          # Nix-Homebrew Module - Makes Homebrew reproducible
          # This locks Homebrew packages to specific versions
          #--------------------------------------------------------------------
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;

              # Install Homebrew for both ARM (native) and x86_64 (Rosetta)
              # Useful for apps that don't have ARM versions yet
              enableRosetta = true;

              # Which user owns the Homebrew installation
              user = user;

              # Lock Homebrew taps to the versions from your flake.lock
              # This means "brew update" won't randomly break things!
              taps = {
                "homebrew/homebrew-core" = homebrew-core;
                "homebrew/homebrew-cask" = homebrew-cask;
              };

              # Prevent manual "brew tap" - all taps must be declared above
              mutableTaps = false;
            };
          }

          #--------------------------------------------------------------------
          # Tap Sync - Keeps your Homebrew config in sync with nix-homebrew
          #--------------------------------------------------------------------
          (
            { config, ... }:
            {
              homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
            }
          )

          #--------------------------------------------------------------------
          # Home Manager - Your Personal User Configuration
          # This manages your dotfiles, shell, and user-level packages
          #--------------------------------------------------------------------
          home-manager.darwinModules.home-manager
          {
            # Use the same nixpkgs as your system config
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            # Backup any existing dotfiles that would be overwritten
            home-manager.backupFileExtension = "bak";

            # Your personal user settings
            home-manager.users.${user} =
              { pkgs, ... }:
              {
                #--------------------------------------------------------------
                # Home Manager Metadata
                #--------------------------------------------------------------
                home = {
                  enableNixpkgsReleaseCheck = false;
                  stateVersion = "25.05";
                };

                #--------------------------------------------------------------
                # Docker Compose CLI plugin (Nix)
                # Makes `docker compose` work via the Nix docker-compose
                #--------------------------------------------------------------
                home.file.".docker/cli-plugins/docker-compose".source =
                  "${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose";

                #--------------------------------------------------------------
                # SSH Config - Manage your SSH keys and host settings
                # This creates your ~/.ssh/config file
                #--------------------------------------------------------------
                programs.ssh = {
                  enable = true;
                  enableDefaultConfig = false;
                  settings = {
                    # GitHub SSH configuration
                    "github.com" = {
                      IdentityFile = "~/.ssh/id_ed25519";
                      IdentitiesOnly = true;
                      AddKeysToAgent = "yes"; # Auto-load key into ssh-agent
                      UseKeychain = "yes"; # Store passphrase in macOS Keychain
                    };
                  };
                };

                #--------------------------------------------------------------
                # Git Config - Your version control settings
                # This creates your ~/.gitconfig file
                #--------------------------------------------------------------
                programs.git = {
                  enable = true;
                  settings = {
                    user = {
                      name = "bryanprimus";
                      email = "bryantobing0@gmail.com";
                    };
                    # Use "main" instead of "master" for new repos
                    init.defaultBranch = "main";

                    # Only allow git pull to fast-forward; fail on divergence.
                    # Forces explicit choice per-invocation: --rebase or --no-rebase (merge).
                    pull.ff = "only";
                  };
                };

                # Zsh Config - Your shell configuration
                # This manages your ~/.zshrc
                programs.zsh = {
                  enable = true;
                  enableCompletion = true; # Press TAB to autocomplete
                  autosuggestion.enable = true; # Fish-style suggestions
                  syntaxHighlighting.enable = true; # Color your commands

                  # Custom code that runs when you open a terminal
                  initContent = ''
                    # bun global path
                    export PATH="$HOME/.bun/bin:$PATH"

                    # libpq postgresql
                    # export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

                    # Free up a port by gracefully killing the process using it
                    freeport() {
                      local pids
                      pids=$(lsof -t -i tcp:"$1")
                      if [ -n "$pids" ]; then
                        echo "Gracefully stopping processes on port $1..."
                        echo "$pids" | xargs kill -15
                        sleep 1

                        local remaining_pids
                        remaining_pids=$(lsof -t -i tcp:"$1")
                        if [ -n "$remaining_pids" ]; then
                          echo "Processes did not stop. Force killing..."
                          echo "$remaining_pids" | xargs kill -9
                        fi
                        echo "Port $1 is now free."
                      else
                        echo "No process found running on port $1."
                      fi
                    }
                  '';
                };

                #--------------------------------------------------------------
                # Oh My Posh Config - Customize your shell prompt
                # See more options: https://ohmyposh.dev/docs
                #--------------------------------------------------------------
                programs.starship = {
                  enable = true;
                  enableZshIntegration = true;

                  settings = {
                    add_newline = false;

                    character = {
                      success_symbol = "[❯](bold green)";
                      error_symbol = "[❯](bold red)";
                    };
                  };
                };

                programs.zoxide = {
                  enable = true;
                  enableZshIntegration = true;
                };

                programs.fzf = {
                  enable = true;
                  enableZshIntegration = true;
                };
              };
          }
        ];
      };
    };
}

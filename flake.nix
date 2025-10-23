{
  #============================================================================
  # Flake Description
  #============================================================================
  description = "Declarative macOS config for Bryan's MacBook Pro (aarch64-darwin) using nix-darwin, nix-homebrew, and home-manager; locks Homebrew taps via flake.";

  #============================================================================
  # Flake Inputs - External Dependencies
  # Think of these as the "ingredients" for your system configuration
  #============================================================================
  inputs = {
    # nixpkgs: The main package repository (like npm, but for everything)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # nix-darwin: The framework that lets you configure macOS declaratively
    # This is what makes "darwin-rebuild" work
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # nix-homebrew: Manages Homebrew declaratively (no more manual brew installs!)
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

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

  #============================================================================
  # Flake Outputs - Your System Configuration
  #============================================================================
  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      home-manager,
    }:
    let
      # Your username - change this if you have a different user
      user = "bryan";

      #========================================================================
      # Main System Configuration
      #========================================================================
      configuration =
        { pkgs, ... }:
        {
          # Set up your user account
          system.primaryUser = user;
          users.users.${user}.home = "/Users/${user}";

          #--------------------------------------------------------------------
          # System Packages - CLI tools installed system-wide
          # Search for more packages at: https://search.nixos.org/packages
          #--------------------------------------------------------------------
          environment.systemPackages = with pkgs; [
            vim # Classic text editor
            nixfmt-rfc-style # Formats your Nix code (like prettier/black)
            starship # Beautiful cross-shell prompt
            bun # Bun is a fast, modern JavaScript runtime
          ];

          #--------------------------------------------------------------------
          # Nix Settings - Enables flakes and the new nix commands
          #--------------------------------------------------------------------
          nix.settings.experimental-features = "nix-command flakes";

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
              "rectangle" # Window manager (like Magnet/Spectacle)
              "arc" # Browser
              "cursor" # AI-powered VS Code fork
              "whatsapp" # Messaging app
              "chatgpt" # AI-powered chatbot desktop app
              "cleanshot" # Screenshot tool
              "telegram" # Messaging app
              "zed" # Code editor
              "outerbase-studio" # sql gui client
              "chatgpt-atlas" # AI-powered browser
            ];

            # CLI applications
            brews = [
              "node"
              "watchman" # For react native development
              "cocoapods" # For iOS development

              "unar" # archive extractor
              "sqlite" # SQL client
            ];

            # Homebrew package repositories
            taps = [ "homebrew/cask" ];

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
                # SSH Config - Manage your SSH keys and host settings
                # This creates your ~/.ssh/config file
                #--------------------------------------------------------------
                programs.ssh = {
                  enable = true;
                  enableDefaultConfig = false;
                  matchBlocks = {
                    # GitHub SSH configuration
                    "github.com" = {
                      identityFile = "~/.ssh/id_ed25519";
                      identitiesOnly = true;
                      extraOptions = {
                        AddKeysToAgent = "yes"; # Auto-load key into ssh-agent
                        UseKeychain = "yes"; # Store passphrase in macOS Keychain
                      };
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
                  };
                };

                #--------------------------------------------------------------
                # Zsh Config - Your shell configuration
                # This manages your ~/.zshrc
                #--------------------------------------------------------------
                programs.zsh = {
                  enable = true;
                  enableCompletion = true; # Press TAB to autocomplete
                  autosuggestion.enable = true; # Fish-style suggestions
                  syntaxHighlighting.enable = true; # Color your commands

                  # Custom code that runs when you open a terminal
                  initContent = ''
                    # force the use of sqlite3 homebrew instead of the default by macOS
                    export PATH="/opt/homebrew/opt/sqlite/bin:$PATH"


                    # Start Starship prompt
                    eval "$(starship init zsh)"

                    # Function: update_terminal_cwd
                    # Purpose: Notifies your terminal emulator of the current working directory
                    # This is especially useful for features like "Open new tab here" (e.g., Cmd+T in iTerm2 or Terminal.app on macOS),
                    # allowing new tabs or splits to start in the same directory as your current shell.
                    # It works by emitting a special escape sequence (\e]7;) with the current directory encoded as a file:// URL.
                    # This is a standard used by many modern terminal emulators to track shell location.
                    update_terminal_cwd() {
                      local url_path=""
                      {
                        local i ch hexch LC_CTYPE=C LC_ALL=
                        # Loop through each character in $PWD and percent-encode if needed
                        for ((i = 1; i <= ''${#PWD}; ++i)); do
                          ch="$PWD[i]"
                          if [[ "$ch" =~ [/._~A-Za-z0-9-] ]]; then
                            url_path+="$ch"
                          else
                            printf -v hexch "%02X" "'$ch"
                            url_path+="%$hexch"
                          fi
                        done
                      }
                      # Send the escape sequence to update the terminal's idea of the current directory
                      printf '\e]7;%s\a' "file://$(hostname)$url_path"
                    }

                    # Ensure update_terminal_cwd runs before each prompt is displayed,
                    # so the terminal always knows your up-to-date location.
                    autoload -Uz add-zsh-hook
                    add-zsh-hook precmd update_terminal_cwd
                  '';
                };

                #--------------------------------------------------------------
                # Starship Config - Customize your shell prompt
                # See more options: https://starship.rs/config/
                #--------------------------------------------------------------
                programs.starship = {
                  enable = true;
                  settings = {
                    # Don't add empty line before prompt (more compact)
                    add_newline = false;
                  };
                };
              };
          }
        ];
      };
    };
}

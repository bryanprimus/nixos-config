{
  description = "Bryan's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-bundle,
      home-manager,
      ...
    }:
    let
      user = "bryan";
      system = "aarch64-darwin";
      configuration =
        { pkgs, ... }:
        {
          # Add user configuration part of home-manager ?
          users.users.${user} = {
            name = user;
            home = "/Users/${user}";
          };

          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget

          environment.systemPackages = with pkgs; [
            vim
            nodejs
            nixfmt-rfc-style
            bun
            starship
          ];

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          # Enable alternative shell support in nix-darwin.
          # programs.fish.enable = true;

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 6;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = system;

          homebrew = {
            enable = true;
            casks = [
              "rectangle"
              "whatsapp"
              "cleanshot"
              "ghostty"
              "chatgpt"
              "trae"
            ];
            taps = [ "homebrew/cask" ];
            onActivation = {
              cleanup = "zap";
            };
          };

        };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#Bryans-MacBook-Pro
      darwinConfigurations."Bryans-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              # Install Homebrew under the default prefix
              enable = true;

              # User owning the Homebrew prefix
              user = user;

              # Optional: Declarative tap management
              taps = {
                "homebrew/homebrew-core" = homebrew-core;
                "homebrew/homebrew-cask" = homebrew-cask;
                "homebrew/homebrew-bundle" = homebrew-bundle;
              };

              # Optional: Enable fully-declarative tap management
              # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
              mutableTaps = false;
              autoMigrate = true;
            };
          }
          home-manager.darwinModules.home-manager
          {
            # Enable home-manager
            home-manager = {
              useGlobalPkgs = true;
              users.${user} =
                { pkgs, ... }:
                {
                  home = {
                    enableNixpkgsReleaseCheck = false;
                    stateVersion = "23.11";

                  };

                  # Zsh configuration
                  programs.zsh = {
                    enable = true;
                    enableCompletion = true;
                    autosuggestion.enable = true;
                    syntaxHighlighting.enable = true;

                    initExtra = ''
                      # Initialize Starship prompt
                      eval "$(starship init zsh)"
                    '';
                  };

                  # Starship configuration
                  programs.starship = {
                    enable = true;
                    settings = {
                      # Disable the newline at the start of the prompt
                      add_newline = false;
                    };
                  };

                  # SSH configuration
                  programs.ssh = {
                    enable = true;
                    matchBlocks = {
                      "github.com" = {
                        identityFile = "~/.ssh/id_ed25519";
                        identitiesOnly = true;
                        extraOptions = {
                          AddKeysToAgent = "yes";
                          UseKeychain = "yes";
                        };
                      };
                    };
                  };

                  # Git configuration
                  programs.git = {
                    enable = true;
                    userName = "bryanprimus";
                    userEmail = "bryantobing0@gmail.com";
                  };

                  # Marked broken Oct 20, 2022 check later to remove this
                  # https://github.com/nix-community/home-manager/issues/3344
                  manual.manpages.enable = false;
                };
            };
          }
        ];
      };
    };
}

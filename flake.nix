{
  description = "Bryan's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # Optional: Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
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
      home-manager,
    }:
    let
      user = "bryan";

      configuration =
        { pkgs, ... }:
        {
          system.primaryUser = user;
          users.users.${user}.home = "/Users/${user}";

          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          environment.systemPackages = [
            pkgs.vim
            pkgs.nixfmt-rfc-style
            pkgs.starship
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
          nixpkgs.hostPlatform = "aarch64-darwin";

          homebrew = {
            enable = true;
            casks = [
              "rectangle"
              "arc"
              "cursor"
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

              # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
              enableRosetta = true;

              # User owning the Homebrew prefix
              user = user;

              # Optional: Declarative tap management
              taps = {
                "homebrew/homebrew-core" = homebrew-core;
                "homebrew/homebrew-cask" = homebrew-cask;
              };

              # Optional: Enable fully-declarative tap management
              #
              # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
              mutableTaps = false;
            };
          }
          # Optional: Align homebrew taps config with nix-homebrew
          (
            { config, ... }:
            {
              homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
            }
          )
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${user} =
              { pkgs, ... }:
              {
                home = {
                  enableNixpkgsReleaseCheck = false;
                  stateVersion = "25.05";
                };

                # SSH configuration
                programs.ssh = {
                  enable = true;
                  enableDefaultConfig = false;
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
                  extraConfig = {
                    init.defaultBranch = "main";
                  };
                };

                programs.zsh = {
                  enable = true;
                  enableCompletion = true;
                  autosuggestion.enable = true;
                  syntaxHighlighting.enable = true;
                  initContent = ''
                    	# Initialize Starship
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
              };

            # Optionally, use home-manager.extraSpecialArgs to pass
            # arguments to home.nix
          }
        ];
      };
    };
}

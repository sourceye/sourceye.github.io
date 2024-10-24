{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    agenix-shell.url = "github:aciceri/agenix-shell";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    agenix-shell,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      installationScript = agenix-shell.packages.${system}.installationScript.override {
        agenixShellConfig.secrets = {
          TF_VAR_notion_api_key.file = ./secrets/TF_VAR_notion_api_key.age;
          TF_VAR_notion_db_id.file = ./secrets/TF_VAR_notion_db_id.age;
          _GOOGLE_APPLICATION_CREDENTIALS = {
            file = ./secrets/GOOGLE_APPLICATION_CREDENTIALS.age;
            namePath = "GOOGLE_APPLICATION_CREDENTIALS";
          };
        };
      };
    in {
      devShell = with pkgs;
        mkShell {
          buildInputs = [
            nodejs
            terraform
          ];
          shellHook = ''
            source ${lib.getExe installationScript}
          '';
        };
    });
}

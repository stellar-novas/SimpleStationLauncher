{
  description = "Flake providing a package for the SimpleStation14 Launcher.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.11";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      ...
    }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: function (import nixpkgs { inherit system; })
        );
      isousername = "ss14-developer";
    in
    {
      packages = forAllSystems (pkgs: {
        default = self.packages.${pkgs.system}.space-station-14-launcher;
        space-station-14-launcher = pkgs.callPackage ./nix/package-git.nix { };

        test-env-image = nixos-generators.nixosGenerate {
          system = pkgs.system;
          format = "iso";
          modules = [
            {
              imports = [
                "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
              ];

              users.users.isouser = {
                name = isousername;
                isNormalUser = true;
                createHome = true;
              };

              services.pipewire = {
                enable = true;
                alsa.enable = true;
                alsa.support32Bit = true;
                pulse.enable = true;
              };

              fileSystems."/xdg-data" = {
                fsType = "9p";
                label = "xdg-data";
                options = [
                  "trans=virtio"
                ];
              };

              fileSystems."/app" = {
                fsType = "9p";
                label = "app-path";
                options = [
                  "trans=virtio"
                ];
              };

              services.cage = {
                enable = true;
                user = isousername;
                environment = {
                  XDG_DATA_HOME = "/xdg-data";
                };
                program = "/app/bin/SS14.Launcher";
              };

              system.stateVersion = "24.11";
            }
          ];
        };

        test-x86-linux = pkgs.writeShellScriptBin "test-launcher-x86" ''
          ${pkgs.qemu}/bin/qemu-system-x86_64 \
            -cpu max \
            -m 2G \
            -smp 4 \
            -drive file=${self.packages.x86_64-linux.test-env-image}/iso/nixos.iso,media=cdrom,readonly=on \
            -virtfs local,path=$XDG_DATA_HOME,mount_tag=xdg-data,security_model=passthrough,id=xdg-data \
            -virtfs local,path=${
              self.packages.${pkgs.system}.default
            },mount_tag=app-path,security_model=passthrough,id=app-path \
            -vga qxl
        '';

      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}

{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs?ref=nixpkgs-unstable";
    };
    nixos-apple-silicon = {
      url = "github:yuyuyureka/nixos-apple-silicon/minimize-patches";
      flake = false;
    };
    __flake-compat = {
      url = "git+https://git.lix.systems/lix-project/flake-compat.git";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      nixos-apple-silicon,
      ...
    }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      overlay = import ./overlay.nix { inherit nixos-apple-silicon; };
      pkgs' = pkgs.extend overlay;
    in
    {
      overlays.default = overlay;

      packages.${system} = {
        inherit (pkgs')
          mesa
          muvm
          fex
          fex-x86_64-rootfs
          ;
        mesa-x86_64-linux = pkgs'.pkgsCross.gnu64.mesa;
      };
    };
}

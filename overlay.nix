let
  inputs = import ./inputs.nix;
in
{
  nixpkgs-muvm ? inputs.nixpkgs-muvm,
  nixos-apple-silicon ? inputs.nixos-apple-silicon,
}:
let
  getMesaShouldCross =
    pkgs:
    let
      cfg = pkgs.config.nixos-muvm-fex or { };
    in
    cfg.mesaDoCross or true;

  x86_64-linux-pkgs =
    pkgs:
    import pkgs.path {
      inherit (pkgs) config overlays;
      localSystem = "x86_64-linux";
    };

  # This overlay assumes all previous required overlays have been applied
  overlay = final: prev: {
    virglrenderer = prev.virglrenderer.overrideAttrs (old: {
      src = final.fetchurl {
        url = "https://gitlab.freedesktop.org/asahi/virglrenderer/-/archive/asahi-20241205.2/virglrenderer-asahi-20241205.2.tar.bz2";
        hash = "sha256-mESFaB//RThS5Uts8dCRExfxT5DQ+QQgTDWBoQppU7U=";
      };
      mesonFlags = old.mesonFlags ++ [ (final.lib.mesonOption "drm-renderers" "asahi-experimental") ];
    });
    mesa-asahi-edge = final.callPackage ./mesa.nix { inherit (prev) mesa-asahi-edge; };
    mesa-asahi-edge-x86_64 =
      if getMesaShouldCross final then
        final.pkgsCross.gnu64.mesa-asahi-edge
      else
        (x86_64-linux-pkgs final).mesa-asahi-edge;
    mesa-x86_64-linux = final.mesa-asahi-edge-x86_64;
    muvm = final.callPackage ./muvm.nix {
      inherit (prev) muvm;
    };
    fex = final.callPackage ./fex.nix { };
    fex-x86_64-rootfs = final.runCommand "fex-rootfs" { nativeBuildInputs = [ final.erofs-utils ]; } ''
      mkdir -p rootfs/run/opengl-driver
      cp -R "${final.mesa-x86_64-linux}"/* rootfs/run/opengl-driver/
      mkfs.erofs $out rootfs/
    '';
  };

  nixos-apple-silicon-overlay = import "${nixos-apple-silicon}/apple-silicon-support/packages/overlay.nix";

  # Overlay which applies changes from https://github.com/NixOS/nixpkgs/pull/397932
  # Only gets applied if there's no muvm package
  muvm-overlay =
    final: prev:
    if prev ? muvm then
      { }
    else
      {
        libkrunfw = final.callPackage "${nixpkgs-muvm}/pkgs/by-name/li/libkrunfw/package.nix" { };
        libkrun = final.callPackage "${nixpkgs-muvm}/pkgs/by-name/li/libkrun/package.nix" { };
        muvm = final.callPackage "${nixpkgs-muvm}/pkgs/by-name/mu/muvm/package.nix" { };
      };

  overlays = [
    nixos-apple-silicon-overlay
    muvm-overlay
    overlay
  ];
in
final: # The final argument is shared between all overlays
prev:
prev.lib.foldl' (result: overlay: result // overlay final (prev // result)) { } overlays

let
  inputs = import ./inputs.nix;
in
{
  nixos-apple-silicon ? inputs.nixos-apple-silicon,
}:
let
  getMesaShouldCross =
    pkgs: hasMesaFork:
    let
      cfg = pkgs.config.nixos-muvm-fex or { };
    in
    # Default to building natively if we're not using the Asahi fork,
    # since it will probably be in cache.nixos.org.
    cfg.mesaDoCross or hasMesaFork;

  x86_64-linux-pkgs =
    pkgs:
    import pkgs.path {
      inherit (pkgs) config overlays;
      localSystem = "x86_64-linux";
    };

  i686-linux-pkgs =
    pkgs:
    import pkgs.path {
      inherit (pkgs) config overlays;
      localSystem = "i686-linux";
    };

  # This overlay assumes all previous required overlays have been applied
  # Also overrides mesa and virglrenderer to asahi forks, but only if mesa is pre-uAPI-merge.
  overlay =
    final: prev:
    let
      hasMesaFork = final.lib.versionOlder prev.mesa.version "25.1.1";
      mesa = if hasMesaFork then "mesa-asahi-edge" else "mesa";
    in
    {
      virglrenderer = prev.virglrenderer.overrideAttrs (old: {
        src = final.fetchurl {
          url = "https://gitlab.freedesktop.org/asahi/virglrenderer/-/archive/asahi-20250424/virglrenderer-asahi-20250424.tar.bz2";
          hash = "sha256-9qFOsSv8o6h9nJXtMKksEaFlDP1of/LXsg3LCRL79JM=";
        };
        mesonFlags = old.mesonFlags ++ [ (final.lib.mesonOption "drm-renderers" "asahi-experimental") ];
      });
      mesa = final.callPackage ./mesa.nix { inherit (prev) mesa; };
      mesa-x86_64-linux =
        if getMesaShouldCross final hasMesaFork then
          final.pkgsCross.gnu64.${mesa}
        else
          (x86_64-linux-pkgs final).${mesa};
      mesa-i686-linux =
        if getMesaShouldCross final hasMesaFork then
          final.pkgsCross.gnu32.${mesa}
        else
          (i686-linux-pkgs final).${mesa};
      muvm = final.callPackage ./muvm.nix {
        inherit (prev) muvm;
      };
      fex = final.callPackage ./fex.nix { };
      fex-x86-rootfs = final.runCommand "fex-rootfs" { nativeBuildInputs = [ final.erofs-utils ]; } ''
        mkdir -p rootfs/run/opengl-driver
        mkdir -p rootfs/run/opengl-driver-32
        cp -R "${final.mesa-x86_64-linux}"/* rootfs/run/opengl-driver/
        cp -R "${final.mesa-i686-linux}"/* rootfs/run/opengl-driver-32/
        mkfs.erofs $out rootfs/
      '';
    };

  nixos-apple-silicon-overlay = import "${nixos-apple-silicon}/apple-silicon-support/packages/overlay.nix";

  overlays = [
    nixos-apple-silicon-overlay
    overlay
  ];
in
final: # The final argument is shared between all overlays
prev:
prev.lib.foldl' (result: overlay: result // overlay final (prev // result)) { } overlays

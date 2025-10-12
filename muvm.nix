{
  lib,
  muvm,
  stdenv,
  passt,
  dhcpcd,
  socat,
  coreutils,
  fex,
  withFex ? stdenv.isAarch64,
  fex-x86-rootfs,
  fexRootFS ? if withFex then fex-x86-rootfs else null,
  findutils,
  util-linux,
  writeShellApplication,
  fuse,
  mesa-x86_64-linux,
  hardcodedMesa ? withFex,
}:
let
  binPath = lib.makeBinPath (
    [
      dhcpcd
      passt
      (placeholder "out")
      socat
    ]
    ++ lib.optionals withFex [ fex ]
  );

  mesaDir = if hardcodedMesa then mesa-x86_64-linux else "/run/muvm-host/run/opengl-driver";
  initScript = writeShellApplication {
    name = "muvm-init";
    runtimeInputs = [
      coreutils
      util-linux
      findutils
    ];
    text = ''
      ln -s /run/muvm-host/run/current-system /run/current-system
      ln -s ${mesaDir} /run/opengl-driver

      # Set up fusermount suid wrapper. Needed for FEX
      mkdir -p /run/wrappers
      mount -t tmpfs -o exec,suid tmpfs /run/wrappers
      mkdir -p /run/wrappers/bin
      cp "${lib.getExe' fuse "fusermount"}" /run/wrappers/bin/fusermount
      chown root:root /run/wrappers/bin/fusermount
      chmod u=srx,g=x,o=x /run/wrappers/bin/fusermount
    '';
  };

  wrapperArgs = lib.escapeShellArgs (
    [
      "--prefix"
      "PATH"
      ":"
      binPath
      "--add-flags"
      "--execute-pre=${lib.getExe initScript}"
    ]
    ++ lib.optionals (withFex && fexRootFS != null) [
      # TODO: Doesn't actually currently work
      "--add-flags"
      "--fex-image=${fexRootFS}"
    ]
  );
in
assert lib.assertMsg (withFex -> stdenv.isAarch64) "FEX only support aarch64 hosts";
muvm.overrideAttrs {
  # Replace nixpkgs wrapper with ours
  postFixup = ''
    wrapProgram $out/bin/muvm ${wrapperArgs}
  '';
}

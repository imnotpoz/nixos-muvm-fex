# Copied from https://github.com/NixOS/nixpkgs/blob/20ffafc111247895104a690483851c421a4c1d3e/pkgs/by-name/fe/fex/package.nix
{
  fetchFromGitHub,
  lib,
  llvmPackages,
  cmake,
  ninja,
  pkg-config,
  gitMinimal,
  qt5,
  python3,
  erofs-utils,
  makeWrapper,
}:
let
  binPath = lib.makeBinPath [ erofs-utils ];
  wrapperArgs = lib.escapeShellArgs [
    "--prefix"
    "PATH"
    ":"
    binPath
  ];
in
llvmPackages.stdenv.mkDerivation (finalAttrs: rec {
  pname = "fex";
  version = "2510";

  src = fetchFromGitHub {
    owner = "FEX-Emu";
    repo = "FEX";
    tag = "FEX-${version}";
    hash = "sha256-Uxq7xMSjNZSE9Q0yRQUmjGscX3fqXvXbA2ZRSDZMr4U=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    gitMinimal
    qt5.wrapQtAppsHook
    llvmPackages.bintools

    (python3.withPackages (
      pythonPackages: with pythonPackages; [
        setuptools
        libclang
      ]
    ))

    makeWrapper
  ];

  buildInputs = with qt5; [
    qtbase
    qtdeclarative
    qtquickcontrols
    qtquickcontrols2
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DUSE_LINKER=lld"
    "-DENABLE_LTO=True"
    "-DENABLE_ASSERTIONS=False"
    (lib.cmakeBool "BUILD_TESTS" finalAttrs.finalPackage.doCheck)
  ];

  strictDeps = true;
  doCheck = false; # broken on Apple silicon computers

  # Avoid wrapping anything other than FEXConfig, since the wrapped executables
  # don't seem to work when registered as binfmts.
  dontWrapQtApps = true;
  preFixup = ''
    wrapQtApp "$out/bin/FEXConfig" ${wrapperArgs}
    wrapProgram "$out/bin/FEXServer" ${wrapperArgs}
  '';

  meta = {
    description = "Fast usermode x86 and x86-64 emulator for Arm64 Linux";
    homepage = "https://fex-emu.com/";
    platforms = [ "aarch64-linux" ];
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ nrabulinski ];
    mainProgram = "FEXBash";
  };
})

{
  lib,
  stdenv,
  mesa,
  llvm,
  buildPackages,
  fetchFromGitLab,
  libdisplay-info,
}:
let
  isCross = stdenv.hostPlatform != stdenv.buildPlatform;
in
  (mesa.overrideAttrs (old: {
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "mesa";
      repo = "mesa";
      rev = "9bb74929bc3df5c00a1b41c24c700775c57959be";
      hash = "sha256-8Cx661bdRsxTi3BvpA8bhXc5ZCncBSLIDSkPLoGMlE4=";
    };

    postInstall =
      old.postInstall or ""
      + ''
        moveToOutput bin/vtn_bindgen2 $cross_tools
        moveToOutput bin/asahi_clc $cross_tools
      '';

    LLVM_CONFIG_PATH = lib.optionalDrvAttr isCross "${llvm.dev}/bin/llvm-config-native";

    mesonFlags =
      old.mesonFlags or []
      ++ [
        (lib.mesonBool "spirv-to-dxil" true)
      ];

    buildInputs =
      old.buildInputs or []
      ++ [
        libdisplay-info
      ];

    nativeBuildInputs =
      old.nativeBuildInputs or []
      ++ lib.optionals isCross [
        buildPackages.mesa.cross_tools or null
      ];
  })).override {
    galliumDrivers = [
      "d3d12"
      "virgl"
      "asahi"
      "llvmpipe"
      "zink"
      "softpipe"
    ];
    vulkanDrivers = [
      "virtio"
      "asahi"
      "swrast"
    ];
    vulkanLayers = [
        "device-select"
    ];
  }

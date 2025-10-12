{
  lib,
  stdenv,
  mesa,
  llvm,
  buildPackages,
  fetchFromGitLab,
  libdisplay-info,
  v4l-utils,
}:
let
  isCross = stdenv.hostPlatform != stdenv.buildPlatform;
in
  (mesa.overrideAttrs (old: {
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "mesa";
      repo = "mesa";
      tag = "mesa-25.2.3";
      hash = "sha256-3URQ9ZZ22vdZpToZqpWbcpsAI4e8a5X35/5HWOprbPM=";
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
        (libdisplay-info.overrideAttrs {
          v4l-utils = v4l-utils.override {
            withGUI = false;
          };
        })
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

{
  description = "C/CPP dev flake";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nix-bundle-app.url = "github:WinterMaximus/nix-bundler";
  };
  outputs = {
    nixpkgs,
    nix-bundle-app,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    bundler = nix-bundle-app.lib.mkLib pkgs;

    pname = "main"; # Also change in CMakeLists.txt
    version = "0.1.0";
    src = ./.;
    info = {
      maintainer = "Max <maxwerberg@gmail.com>";
      summary = pname; # Required for rpm, free to change later
      # homepage = "https://example.com";
      # license = "MIT";
    };

    mainDrvLinux = pkgs.stdenv.mkDerivation {
      inherit pname;
      inherit version;
      inherit src;
      nativeBuildInputs = [pkgs.cmake];
      cmakeFlags = [
        "-DCMAKE_BUILD_TYPE=Release"
      ];
      buildInputs = [
        # Librarys/Deps
      ];
    };
    pkgsCrossWindows = pkgs.pkgsCross.mingwW64;
    mainDrvWindows = pkgsCrossWindows.stdenv.mkDerivation {
      inherit pname;
      inherit version;
      inherit src;
      nativeBuildInputs = [pkgsCrossWindows.buildPackages.cmake];
      cmakeFlags = [
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_SYSTEM_NAME=Windows"
      ];
      buildInputs = [
        # Librarys/Deps (for windows)
      ];
    };
  in {
    packages.${system} = {
      default = mainDrvLinux;
      bundles-linux = bundler.bundleAll {
        drv = mainDrvLinux;
        inherit info;
        formats = ["deb" "archlinux" "flatpak" "tar.gz" "appimage" "rpm"];
      };
      bundles-windows = bundler.bundleAll {
        drv = mainDrvWindows;
        inherit info;
        formats = ["nsis" "msi"];
        target = {
          arch = "x86_64";
          os = "windows";
        };
      };
    };

    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        gcc
        clang-tools
        cmake
        (pkgs.writeShellScriptBin "prep" "cmake -B build") # For debug
        (pkgs.writeShellScriptBin "build" "prep && cmake --build build")
        (pkgs.writeShellScriptBin "run" "build && ./build/${pname}")

        (pkgs.writeShellScriptBin "build-nix" "rm -rf build && nix build path:.") # For release
        (pkgs.writeShellScriptBin "run-nix" "rm -rf build && build-nix && nix run path:.")

        (pkgs.writeShellScriptBin "bundle-linux" "rm -f result && nix build path:.#bundles-linux") # Always run in project root!
        (pkgs.writeShellScriptBin "bundle-windows" "rm -f result && nix build path:.#bundles-windows")
      ];
      shellHook = ''
        echo "Entering c++ environment"
      '';
    };
  };
}

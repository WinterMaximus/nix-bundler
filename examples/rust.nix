{
  description = "Rust dev flake";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nix-bundle-app.url = "github:WinterMaximus/nix-bundler";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    nixpkgs,
    nix-bundle-app,
    fenix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    bundler = nix-bundle-app.lib.mkLib pkgs;

    nightly = false;
    rustToolchain =
      if nightly
      then fenix.packages.${system}.complete.toolchain
      else fenix.packages.${system}.stable.toolchain;
    rustPlatform = pkgs.makeRustPlatform {
      cargo = rustToolchain;
      rustc = rustToolchain;
    };

    pname = "main"; # Ensure that this matches Cargo.toml
    version = "0.1.0";
    src = ./.;
    cargoLock = {
      lockFile = ./Cargo.lock;
      outputHashes = {
        # For git deps in Cargo.toml
        # "somecrate-0.1.0" = lib.fakeHash;
      };
    };

    info = {
      maintainer = "Max <maxwerberg@gmail.com>";
      summary = pname; # Required for rpm, free to change later
      # homepage = "https://example.com";
      # license = "MIT";
    };

    mainDrvLinux = rustPlatform.buildRustPackage {
      inherit pname;
      inherit version;
      inherit src;
      inherit cargoLock;
      buildInputs = with pkgs; [
        # Additional build deps for linux
      ];
      meta.description = info.summary; # Required for rpm
    };

    pkgsCrossWindows = pkgs.pkgsCross.mingwW64;
    mainDrvWindows = pkgsCrossWindows.rustPlatform.buildRustPackage {
      # Will build with nightly but may not work properly
      inherit pname;
      inherit version;
      inherit src;
      inherit cargoLock;
      buildInputs = with pkgs; [
        # Additional build deps for windows
      ];
      meta.description = info.summary;
    };
  in {
    packages.${system} = {
      default = mainDrvLinux;
      inherit info;
      bundles-linux = bundler.bundleAll {
        drv = mainDrvLinux;
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
        rustToolchain
        pkg-config
        openssl

        (pkgs.writeShellScriptBin "build" "cargo build") # For debug
        (pkgs.writeShellScriptBin "run" "cargo run")
        (pkgs.writeShellScriptBin "build-nix" "check && rm -f result && nix build path:.") # Ensure pname here and name in Cargo.toml match!
        (pkgs.writeShellScriptBin "run-nix" "check && rm -f result && build-nix && nix run path:.")

        (pkgs.writeShellScriptBin "bundle-linux" "rm -f result && check && nix build path:.#bundles-linux") # Always run in project root!
        (pkgs.writeShellScriptBin "bundle-windows" "rm -f result && check && nix build path:.#bundles-windows")

        (pkgs.writeShellScriptBin "cln" "cargo clean && rm -f result")
        (pkgs.writeShellScriptBin "test" "cargo test")
        (pkgs.writeShellScriptBin "check" "cargo check")
        (pkgs.writeShellScriptBin "bench" "cargo bench")
        (pkgs.writeShellScriptBin "upd" "cargo update")
        (pkgs.writeShellScriptBin "fmt" "cargo fmt")
        (pkgs.writeShellScriptBin "pkg" "cargo package")
        (pkgs.writeShellScriptBin "publish" "cargo publish")
        (pkgs.writeShellScriptBin "doc" "cargo doc")
        (pkgs.writeShellScriptBin "lint" "cargo clippy")
        (pkgs.writeShellScriptBin "login" "cargo login")
        (pkgs.writeShellScriptBin "logout" "cargo logout")
      ];
      env.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
      shellHook = ''
        echo "Entering rust environment. Using:"
        rustc --version
      '';
    };
  };
}

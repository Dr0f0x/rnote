{
	description = "Rnote handwriting and sketching application (community maintained)";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

	outputs =
		{ self, nixpkgs }:
		let
			inherit (nixpkgs) lib;
			version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;
			systems = lib.intersectLists lib.systems.flakeExposed lib.platforms.linux;
			forAllSystems = lib.genAttrs systems;
			nixpkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});

			rnotePackage =
				{
					lib,
					rustPlatform,
					pkg-config,
					cmake,
						meson,
						ninja,
					gettext,
					glib,
					gtk4,
					libadwaita,
					cairo,
						libxml2,
					librsvg,
					alsa-lib,
						appstream,
						desktop-file-utils,
					wrapGAppsHook4,
					shared-mime-info,
				}:
				rustPlatform.buildRustPackage {
					pname = "rnote";
					inherit version;
					prefix = placeholder "out";

					src = lib.cleanSource ./.;

					cargoLock = {
						lockFile = ./Cargo.lock;
						allowBuiltinFetchGit = true;
					};

					strictDeps = true;
					doCheck = true;
					phases = [
						"unpackPhase"
						"patchPhase"
						"configurePhase"
						"buildPhase"
						"installPhase"
						"checkPhase"
						"fixupPhase"
					];

					nativeBuildInputs = [
						cmake
						desktop-file-utils
						gettext
						glib
						gtk4
						libxml2
						appstream
						meson
						ninja
						pkg-config
						rustPlatform.bindgenHook
						shared-mime-info
						wrapGAppsHook4
					];

					buildInputs = [
						alsa-lib
						cairo
						glib
						gtk4
						libadwaita
						libxml2
						librsvg
						appstream
					];

					configurePhase = ''
						runHook preConfigure
						meson setup \
							--prefix="$out" \
							--libdir=lib \
							-Dprofile=default \
							-Dcli=true \
							_mesonbuild
						mkdir -p _mesonbuild/cargo-home
						install -Dm644 "$NIX_BUILD_TOP/.cargo/config.toml" _mesonbuild/cargo-home/config.toml
						runHook postConfigure
					'';

					buildPhase = ''
						runHook preBuild
						meson compile -C _mesonbuild
						runHook postBuild
					'';

					installPhase = ''
						runHook preInstall
						meson install -C _mesonbuild

						runHook postInstall
					'';

					postInstall = ''
						gappsWrapperArgs+=(--prefix XDG_DATA_DIRS : "$out/share")
						glib-compile-schemas "$out/share/glib-2.0/schemas"
						update-mime-database "$out/share/mime"
					'';

					preCheck = ''
						schema_dir="$out/share/glib-2.0/schemas"
						mkdir -p "$schema_dir"
						install -m644 \
							_mesonbuild/crates/rnote-ui/data/com.github.flxzt.rnote.gschema.xml \
							"$schema_dir/com.github.flxzt.rnote.gschema.xml"
					'';

					checkPhase = ''
						runHook preCheck
						meson test --no-rebuild --print-errorlogs -C _mesonbuild
						runHook postCheck
					'';

					meta = {
						description = "Sketch and take handwritten notes";
						homepage = "https://rnote.flxzt.net";
						license = lib.licenses.gpl3Plus;
						mainProgram = "rnote";
						platforms = lib.platforms.linux;
					};
				};
		in
		{
			packages = forAllSystems (system: {
				rnote = nixpkgsFor.${system}.callPackage rnotePackage { };
				default = self.packages.${system}.rnote;
			});

			checks = forAllSystems (system: {
				inherit (self.packages.${system}) rnote;
			});

			devShells = forAllSystems (system: {
				default = nixpkgsFor.${system}.mkShell {
					packages = with nixpkgsFor.${system}; [
						cargo
						clippy
						meson
						ninja
						rustc
						rustfmt
					];
					nativeBuildInputs = with nixpkgsFor.${system}; [
						cmake
						gettext
						glib
						gtk4
						libxml2
						meson
						ninja
						appstream
						desktop-file-utils
						pkg-config
						rustPlatform.bindgenHook
						wrapGAppsHook4
					];
					buildInputs = with nixpkgsFor.${system}; [
						alsa-lib
						cairo
						glib
						gtk4
						libadwaita
						librsvg
					];
				};
			});

			formatter = forAllSystems (system: nixpkgsFor.${system}.nixfmt-rfc-style);

			overlays.default = final: _: {
				rnote = final.callPackage rnotePackage { };
			};
		};
}

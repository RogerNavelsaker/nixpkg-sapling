{
  bash,
  bun2nix,
  lib,
  perl,
  symlinkJoin,
}:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  packageVersion =
    manifest.package.version
    + lib.optionalString (
      manifest.package ? packageRevision
    ) "-r${toString manifest.package.packageRevision}";
  aliasOutputs = manifest.binary.aliases or [ ];
  aliasOutputLinks = lib.concatMapStrings (alias: ''
          mkdir -p "${"$" + alias}/bin"
          cat > "${"$" + alias}/bin/${alias}" <<EOF
    #!${lib.getExe bash}
    exec "$out/bin/${manifest.binary.name}" "\$@"
    EOF
          chmod +x "${"$" + alias}/bin/${alias}"
  '') aliasOutputs;
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../package.json
      ../bun.lock
    ];
  };
  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ../bun.nix;
  };
  basePackage = bun2nix.mkDerivation {
    pname = manifest.binary.name;
    version = packageVersion;
    inherit src bunDeps;
    module = "node_modules/${manifest.package.npmName}/${manifest.binary.entrypoint}";
    bunInstallFlags = "--linker=isolated --frozen-lockfile";
    bunCompileToBytecode = false;
    nativeBuildInputs = [ perl ];
    preBuild = ''
      versionFile="node_modules/${manifest.package.npmName}/src/commands/version.ts"
      perl -0pi -e 's/export function getCurrentVersion\(\): string \{\n\tconst pkgPath = join\(import\.meta\.dir, "\.\.", "\.\.", "package\.json"\);\n\tconst pkg = JSON\.parse\(readFileSync\(pkgPath, "utf-8"\)\) as \{ version: string \};\n\treturn pkg\.version;\n\}/export function getCurrentVersion(): string {\n\treturn "${manifest.package.version}";\n}/' "$versionFile"
    '';
    meta = with lib; {
      description = manifest.meta.description;
      homepage = manifest.meta.homepage;
      license = licenses.${manifest.meta.licenseSpdx} or licenses.unfree;
      mainProgram = manifest.binary.name;
      platforms = platforms.linux ++ platforms.darwin;
    };
  };
in
symlinkJoin {
  pname = manifest.binary.name;
  version = packageVersion;
  name = "${manifest.binary.name}-${packageVersion}";
  outputs = [ "out" ] ++ aliasOutputs;
  paths = [ basePackage ];
  postBuild = ''
    ${aliasOutputLinks}
  '';
  meta = basePackage.meta;
}

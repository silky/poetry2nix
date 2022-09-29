{ pkgs
, lib
, poetryLib
, pyProject
, python
, editablePackageSources
}:
let
  name = poetryLib.moduleName pyProject.tool.poetry.name;
  underscoredName = builtins.replaceStrings ["-"] ["_"];

  # Just enough standard PKG-INFO fields for an editable installation
  pkgInfoFields = {
    Metadata-Version = "2.1";
    Name = name;
    # While the pyproject.toml could contain arbitrary version strings, for
    # simplicity we just use the same one for PKG-INFO, even though that
    # should follow follow PEP 440: https://www.python.org/dev/peps/pep-0345/#version
    # This is how poetry transforms it: https://github.com/python-poetry/poetry/blob/6cd3645d889f47c10425961661b8193b23f0ed79/poetry/version/version.py
    Version = pyProject.tool.poetry.version;
    Summary = pyProject.tool.poetry.description;
  };

  pkgInfoFile = builtins.toFile "${name}-PKG-INFO"
    (lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key}: ${value}") pkgInfoFields));

  entryPointsFile = builtins.toFile "${name}-entry_points.txt"
    (lib.generators.toINI { } pyProject.tool.poetry.plugins);

  # A python package that contains simple .egg-info and .pth files for an editable installation
  editablePackage = python.pkgs.toPythonModule (pkgs.runCommand "${name}-editable"
    { } ''
        mkdir -p "$out/${python.sitePackages}"
        cd "$out/${python.sitePackages}"

        # See https://docs.python.org/3.8/library/site.html for info on such .pth files
        # These add another site package path for each line
        touch poetry2nix-editable.pth
        ${lib.concatMapStringsSep "\n"
    (src: ''
          echo "${toString src}" >> poetry2nix-editable.pth
        '')
        (lib.attrValues editablePackageSources)}

        # NEW
        mkdir "${underscoredName}-${pyProject.tool.poetry.version}.dist-info"
        cd "${underscoredName}-${pyProject.tool.poetry.version}.dist-info"
        ln -s ${pkgInfoFile} METADATA
        # ln -s ${entryPointsFile} entry_points.txt
  ''
  );
in
editablePackage

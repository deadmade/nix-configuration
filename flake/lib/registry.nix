let
  registry = dir: let
    entries = builtins.readDir dir;

    visible =
      builtins.filter (name: builtins.substring 0 1 name != ".")
      (builtins.attrNames entries);

    isModuleFile = name:
      entries.${name}
      == "regular"
      && name != "default.nix"
      && builtins.match ".*\\.nix" name != null;

    isDir = name: entries.${name} == "directory";

    stripNix = name: builtins.substring 0 (builtins.stringLength name - 4) name;

    filePairs =
      map (name: {
        name = stripNix name;
        value = import (dir + "/${name}");
      })
      (builtins.filter isModuleFile visible);

    dirPairs = builtins.concatMap (
      name: let
        sub = dir + "/${name}";
        hasDefault = ((builtins.readDir sub)."default.nix" or null) == "regular";
        nested = registry sub;
      in
        if hasDefault
        then [
          {
            inherit name;
            value = import sub;
          }
        ]
        else if nested == {}
        then []
        else [
          {
            inherit name;
            value = nested;
          }
        ]
    ) (builtins.filter isDir visible);

    addUnique = acc: pair:
      if builtins.hasAttr pair.name acc
      then throw "registry: name collision for '${pair.name}' in ${toString dir} ('${pair.name}.nix' file vs '${pair.name}/' directory)"
      else acc // {${pair.name} = pair.value;};
  in
    builtins.foldl' addUnique {} (filePairs ++ dirPairs);
in
  registry

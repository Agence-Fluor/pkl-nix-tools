# pkl-nix-tools

`flake.pkl` décrit le flake avec [`pkl-nix`](https://github.com/Agence-Fluor/pkl-nix).
Le shebang appelle le petit wrapper Bash `pkl-nix-tools`, qui écrit
`.pkl-nix-tools/flake.nix` puis passe la commande à Nix. `flake.lock` reste
à la racine ; le dossier généré peut être supprimé.

## Paquet et développement

`PklProject` versionne le paquet Pkl. Le ZIP publié avec le tag
`pkl-nix-tools@0.1.2` contient **`pkl-nix-tools` et `imports.pkl`** : gardez
ces deux fichiers côte à côte, rendez le script exécutable après extraction
(`chmod +x pkl-nix-tools`) et mettez leur dossier dans votre `PATH`.
Depuis ce checkout :

```sh
export PATH="$PWD:$PATH"
sh scripts/test-package.sh
sh scripts/package-pkl.sh
```

Publiez d'abord `pkl-nix@0.1.0`, puis `pkl-nix-tools@0.1.2` : le
`PklProject` de ce dépôt référence la version publiée de `pkl-nix`.
Pour utiliser le ZIP de release téléchargé :

```sh
unzip pkl-nix-tools@0.1.2.zip -d "$HOME/.local/share/pkl-nix-tools"
chmod +x "$HOME/.local/share/pkl-nix-tools/pkl-nix-tools"
export PATH="$HOME/.local/share/pkl-nix-tools:$PATH"
```

Une dépendance Pkl fournit les modules du paquet ; elle n'installe pas
l'exécutable Bash dans le `PATH`. Le [projet exemple](example/README.md)
référence `pkl-nix` dans son `PklProject`.

## Projet consommateur

Déclarez les versions publiées dans `PklProject` :

```pkl
amends "pkl:Project"
dependencies {
  ["nix"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix/pkl-nix@0.1.0" }
  ["tools"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix-tools/pkl-nix-tools@0.1.2" }
}
```

Après `pkl project resolve`, rendez `flake.pkl` exécutable :

```pkl
#!/usr/bin/env -S pkl-nix-tools
amends "@nix/Flake.pkl"
```

```sh
chmod +x flake.pkl
./flake.pkl generate
./flake.pkl develop
./flake.pkl build .#hello
./flake.pkl run .#hello
./flake.pkl flake check
```

Le wrapper transmet à Nix la référence explicite
`path:/chemin/du/projet?dir=.pkl-nix-tools`. Il ne crée jamais de
`flake.nix` à la racine.

## NixOS

Placez le checkout de `pkl-nix-tools` sous `/etc/nixos/pkl-nix-tools` et
ajoutez ces entrées à la liste `environment.systemPackages` existante de
`configuration.nix` :

```nix
environment.systemPackages = with pkgs; [
  nix pkl
  (runCommand "pkl-nix-tools" {} ''
    mkdir -p $out/bin
    cp ${./pkl-nix-tools/pkl-nix-tools} ${./pkl-nix-tools/imports.pkl} $out/bin/
    chmod +x $out/bin/pkl-nix-tools
  '')
];
```

Puis lancez `sudo nixos-rebuild switch`.

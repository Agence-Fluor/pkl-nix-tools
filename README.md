# pkl-nix-tools

Un petit wrapper Bash autour de **Pkl + Nix**. `flake.pkl` décrit le flake,
Pkl produit le Nix, et Nix gère les builds, shells, applications et locks.
Prérequis : Bash 4+, Pkl 0.31.1+ et Nix avec Flakes.

## Installer depuis Pkl

Dans le `PklProject` du projet :

```pkl
amends "pkl:Project"
dependencies {
  ["nix"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix/pkl-nix@0.1.2" }
  ["tools"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix-tools/pkl-nix-tools@0.1.3" }
}
```

Résolvez les dépendances et installez le wrapper :

```sh
pkl project resolve
pkl run @tools/install.pkl
chmod +x "$HOME/.local/share/pkl-nix-tools/pkl-nix-tools"
export PATH="$HOME/.local/share/pkl-nix-tools:$PATH"
```

L'installateur Pkl extrait le wrapper et `imports.pkl`. Pkl ne fixe pas les
permissions exécutables ; le `chmod` termine l'installation. On peut choisir
un autre dossier avec `--directory /chemin/absolu`.

## Utiliser

```pkl
#!/usr/bin/env -S pkl eval
amends "@nix/Flake.pkl"
import "@nix/Nix.pkl" as Nix
// inputs, packages, devShells, apps, checks…
```

```sh
chmod +x flake.pkl
./flake.pkl                         # afficher le Nix rendu par Pkl
pkl-nix-tools generate              # régénérer uniquement le cache
pkl-nix-tools develop
pkl-nix-tools build .#hello
pkl-nix-tools run .#hello -- argument
pkl-nix-tools flake check
pkl-nix-tools flake update nixpkgs
```

Le shebang lance réellement Pkl. Les commandes Nix passent par le wrapper
pour conserver leur terminal et leur code retour. [L'exemple complet](example/README.md)
fonctionne depuis ce checkout, sans publier ni cloner un autre dépôt.

```text
project/
├── PklProject + PklProject.deps.json  # dépendances Pkl
├── flake.pkl                         # source
├── flake.lock                        # lock Nix normal
└── .pkl-nix-tools/                    # généré et ignoré par Git
    ├── flake.nix
    └── fingerprint
```

Le wrapper trouve le projet depuis les sous-dossiers et utilise
`path:/chemin/absolu/projet?dir=.pkl-nix-tools`. Il conserve tout l'arbre
source : `../message.txt` reste accessible depuis le Nix généré. Aucun
`flake.nix` ni symlink de ce nom n'est créé à la racine.

Le cache suit les imports Pkl locaux transitifs, les projets importés et le
lock Pkl. Un cache valide évite toute évaluation Pkl. Les imports glob sont
réévalués ; après modification d'une ressource lue avec `read()` ou d'une
variable d'environnement, utilisez `generate`. Supprimer `.pkl-nix-tools/`
force sa reconstruction au prochain appel.

Seules les références au flake courant sont réécrites. Les flakes externes
conservent leurs propres locks ; construisez-les séparément du flake courant.
`flake check`, `show`, `metadata`, `archive`, `prefetch`, `lock` et `update`
sont pris en charge. Les commandes qui créent un flake restent accessibles
via `nix`.

## NixOS

Placez le checkout sous `/etc/nixos/pkl-nix-tools`, puis ajoutez à
`configuration.nix` :

```nix
environment.systemPackages = with pkgs; [
  nix pkl
  (runCommand "pkl-nix-tools" { nativeBuildInputs = [ makeWrapper ]; } ''
    mkdir -p $out/libexec/pkl-nix-tools $out/bin
    cp ${./pkl-nix-tools/pkl-nix-tools} ${./pkl-nix-tools/imports.pkl} $out/libexec/pkl-nix-tools/
    chmod +x $out/libexec/pkl-nix-tools/pkl-nix-tools
    patchShebangs $out/libexec/pkl-nix-tools/pkl-nix-tools
    makeWrapper $out/libexec/pkl-nix-tools/pkl-nix-tools $out/bin/pkl-nix-tools \
      --prefix PATH : ${lib.makeBinPath [ bash pkl nix coreutils ]}
  '')
];
```

Appliquez avec `sudo nixos-rebuild switch`.

## Développer et publier

Depuis ce checkout, `export PATH="$PWD:$PATH"` suffit pour utiliser le wrapper.
`sh scripts/test-package.sh` vérifie le cache, les arguments Nix et
l'installation depuis le paquet. `sh scripts/package-pkl.sh` crée les assets.

La version est dans `PklProject`. Après l'avoir commitée :

```sh
tag=$(sh scripts/release-tag.sh)
git tag "$tag"
git push github "$tag"
```

La CI vérifie le tag avant les tests et publie les quatre assets Pkl.

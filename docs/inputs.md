# Référencer un autre flake

`PklProject` déclare les **modules Pkl** utilisés pour décrire le flake.
`inputs` dans `flake.pkl` déclare les **flakes Nix** utilisés pendant son
évaluation. Nix les verrouille dans le `flake.lock` du consommateur.

## Flake Nix distant

Dans un module qui amende `@nix/Flake.pkl` et importe `@nix/Nix.pkl` comme `Nix` :

```pkl
inputs {
  ["nixpkgs"] = new Nix.Input { url = "github:NixOS/nixpkgs/nixos-unstable" }
}
```

Les références `github:owner/repo/tag`, `git+https://…` et les archives HTTPS
suivent les règles [natives de Nix](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-flake.html#flake-references).

## Projet Pkl local

Générez d'abord le flake du projet référencé, après `pkl project resolve` dans ce projet :

```sh
/chemin/commun/flake.pkl generate
```

Puis, dans le consommateur :

```pkl
inputs {
  ["commun"] = new Nix.Input {
    url = "path:/chemin/commun?dir=.pkl-nix-tools"
  }
}
packages {
  ["x86_64-linux"] {
    ["default"] = new Nix.Ref { path = "inputs.commun.packages.x86_64-linux.default" }
  }
}
```

Le préfixe `path:` inclut le répertoire généré même s'il est ignoré par Git.
Utilisez un chemin absolu pour un dépôt voisin : Nix copie chaque arbre de
sources séparément. Un chemin relatif dans le Nix généré part de
`.pkl-nix-tools/` et doit rester dans l'arbre source du flake.

Après modification de `commun`, régénérez-le, puis lancez
`./flake.pkl flake update commun` dans le consommateur. La génération des
inputs n'est pas récursive. Un chemin absolu local n'est pas portable en CI ;
on peut remplacer un input distant pendant le développement avec
`./flake.pkl flake update commun --override-input commun 'path:/chemin/commun?dir=.pkl-nix-tools'`.

## Projet Pkl distant

Nix attend un `flake.nix` : il ne lance ni Pkl ni le shebang d'un input.
Un dépôt GitHub contenant seulement `flake.pkl` n'est donc pas directement
consommable comme flake. `.pkl-nix-tools/` étant ignoré par Git, ajouter
`?dir=.pkl-nix-tools` à l'URL GitHub de ce dépôt ne suffit pas.

Publiez une archive de sources avec `.pkl-nix-tools/flake.nix`. Depuis un
checkout propre et commité, avec les dépendances Pkl résolues :

```sh
./flake.pkl generate
stage=$(mktemp -d)
mkdir -p "$stage/source/.pkl-nix-tools"
git archive HEAD | tar -x -C "$stage/source"
cp .pkl-nix-tools/flake.nix "$stage/source/.pkl-nix-tools/flake.nix"
if [ -f "$stage/source/flake.lock" ]; then
  ln "$stage/source/flake.lock" "$stage/source/.pkl-nix-tools/flake.lock"
fi
tar -czf /tmp/commun-flake.tar.gz -C "$stage" source
rm -rf "$stage"
# Publier /tmp/commun-flake.tar.gz comme asset de release.
```

L'archive conserve tout l'arbre du projet, donc les chemins `../…` du Nix
généré fonctionnent. Elle n'ajoute aucun `flake.nix` à la racine et n'embarque
pas de lock indépendant : les deux noms désignent le même fichier dans
l’archive aussi. Nix peut reprendre les versions des inputs transitifs du
producteur, puis verrouille le graphe complet dans le lock du consommateur.

```pkl
inputs {
  ["commun"] = new Nix.Input {
    url = "https://github.com/owner/commun/releases/download/v1.0.0/commun-flake.tar.gz?dir=.pkl-nix-tools"
    // Facultatif, si les deux projets utilisent nixpkgs :
    inputs { ["nixpkgs"] = new Nix.Input { follows = "nixpkgs" } }
  }
}
```

Le consommateur doit déclarer son propre input `nixpkgs` si `follows` est
utilisé. Nix gère le téléchargement, le hash et le lock de l'archive.
Les releases Pkl actuelles publient les modules Pkl ; cette archive de flake
serait un asset supplémentaire, à publier par le projet producteur.

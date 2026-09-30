# pkl-nix-tools

`./flake.pkl develop`, `build`, `run` : **Pkl décrit le flake, Nix l'exécute**.
Le wrapper Bash vient de la dépendance Pkl du projet. Aucune installation
globale de `pkl-nix-tools`, aucun export de `PATH`, aucun fichier Bash à ajouter
au projet consommateur.

Prérequis système : Bash 4+, Pkl 0.31.1+, Nix avec Flakes et les utilitaires Unix.

## Démarrer

Dans `PklProject` :

```pkl
amends "pkl:Project"
dependencies {
  ["nix"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix/pkl-nix@0.1.2" }
  ["nixTools"] { uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix-tools/pkl-nix-tools@0.2.0" }
}
```

Dans `flake.pkl` :

```pkl
#!/usr/bin/env -S bash -ec 's=$(pkl eval -w "${0%/*}" -x launcher flake.pkl);eval "$s"'
amends "@nix/Flake.pkl"
import "@nix/Nix.pkl" as Nix
local launcher = import("@nixTools/Bootstrap.pkl").output.text
// inputs, packages, devShells, apps, checks…
```

```sh
pkl project resolve
chmod +x flake.pkl
./flake.pkl develop
./flake.pkl build .#hello
./flake.pkl run .#hello -- argument
./flake.pkl flake check
./flake.pkl flake update nixpkgs
./flake.pkl generate                 # forcer la génération uniquement
pkl eval flake.pkl                   # afficher le Nix uniquement
```

Le shebang demande le lanceur à Pkl, puis l’exécute dans le même shell.
La version vient de `PklProject.deps.json` : aucun script à installer ou
à mettre à jour dans le projet. Pkl démarre à chaque appel pour lire le lanceur ;
le rendu Nix et l’analyse des imports sont évités lorsque le cache est valide.
Le relais Bash est nécessaire pour transmettre le terminal et le code retour :
`pkl run` seul ne peut pas lancer `nix develop`.
`./flake.pkl --help` affiche l'usage. Les arguments, le terminal interactif
et le code retour sont transmis à Nix.

## Sources et lock

```text
project/
├── PklProject + PklProject.deps.json
├── flake.pkl
├── flake.lock                       # unique fichier de lock Nix
└── .pkl-nix-tools/                  # généré, ignoré par Git
    ├── flake.nix
    ├── flake.lock                  # lien physique vers ../flake.lock
    └── fingerprint
```

Le lien physique désigne **le même fichier**, sans copie ni lock indépendant.
Il est rétabli à chaque appel si un éditeur a remplacé le lock de la racine.
Nix retrouve ainsi son lock à côté du flake sans appliquer le lock du projet
à ses autres évaluations internes, notamment `nixpkgs` pendant `develop`.

Le flake est adressé par `path:/chemin/projet?dir=.pkl-nix-tools` : tout
l'arbre source reste accessible via `../…`. Aucun `flake.nix` à la racine.
`rm -rf .pkl-nix-tools` conserve le lock racine ; le prochain appel reconstruit
le flake.

Le fingerprint suit les imports Pkl locaux transitifs et le lock Pkl.
Après modification d'une ressource lue par `read()` ou d'une variable
d'environnement, utilisez `generate`. Les imports glob sont réévalués.

Seules les références au flake courant sont réécrites. Commandes prises en
charge : `build`, `develop`, `run`, `flake check|show|metadata|archive|prefetch|lock|update`.
[Exemple complet](example/README.md) · [Inputs locaux et distants](docs/inputs.md).

## NixOS

Les prérequis peuvent être déclarés dans `configuration.nix` :

```nix
environment.systemPackages = with pkgs; [ bash pkl nix ];
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Appliquez avec `sudo nixos-rebuild switch`, puis utilisez les commandes ci-dessus.

## Développer et publier

```sh
pkl project resolve
./flake.pkl develop
sh scripts/test-package.sh
bash scripts/test-e2e.sh
bash scripts/test-inputs.sh
```

Après avoir commité la version de `PklProject` :

```sh
tag=$(sh scripts/release-tag.sh)
git tag "$tag"
git push github "$tag"
```

La CI installe Pkl et Nix, teste l’exécution depuis le paquet et publie les quatre assets Pkl.

Depuis la version 0.2, le lanceur est évalué directement depuis le paquet.
Remplacez l’ancien shebang par celui ci-dessus ; `install.pkl` n’est plus
nécessaire. L’ancien fichier `.pkl-nix-tools/run` est supprimé au prochain appel.

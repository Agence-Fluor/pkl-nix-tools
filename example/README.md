# Exemple complet

`PklProject` importe `pkl-nix` comme dépendance Pkl locale sous l'alias
`nix`. `flake.pkl` est exécutable et décrit un package, une application,
un devShell et un check. Nix conserve son `flake.lock` standard ici.

```sh
export PATH="$(cd .. && pwd):$PATH"  # depuis ce répertoire, sans installation
pkl project resolve               # après un changement de dépendance Pkl
./flake.pkl flake lock
./flake.pkl build
./flake.pkl run .#hello
./flake.pkl develop --command hello-pkl
./flake.pkl flake check
```

L'application lit `message.txt` avec `../message.txt` depuis le Nix généré.
Vous pouvez supprimer `.pkl-nix-tools/` ; la commande suivante le recrée.

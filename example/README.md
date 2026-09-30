# Exemple complet

Le projet référence `pkl-nix` publié et le paquet `pkl-nix-tools` de ce
checkout. Il décrit un package, une application, un devShell et un check.
Depuis ce dossier :

```sh
pkl project resolve
./flake.pkl flake lock
./flake.pkl build
./flake.pkl run .#hello
./flake.pkl develop --command hello-pkl
./flake.pkl flake check
pkl eval flake.pkl                       # afficher le rendu uniquement
```

L'application lit `message.txt` via `../message.txt` depuis le Nix généré.
Le lanceur est extrait automatiquement de la dépendance Pkl locale, sans
commande globale. Le lock de la racine est partagé avec le cache par un lien
physique ; Nix lit et écrit le même fichier.
Vous pouvez supprimer `.pkl-nix-tools/` ; le wrapper le reconstruit.
Pour ajouter un autre projet comme input, voir [les références de flakes](../docs/inputs.md).

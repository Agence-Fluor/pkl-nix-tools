# Exemple complet

Le projet référence `pkl-nix` publié et le paquet `pkl-nix-tools` de ce
checkout. Il décrit un package, une application, un devShell et un check.
Depuis ce dossier :

```sh
pkl project resolve
pkl run install.pkl --directory "$PWD/.tools"
chmod +x .tools/pkl-nix-tools
export PATH="$PWD/.tools:$PATH"
./flake.pkl                              # rendu Pkl → Nix
pkl-nix-tools flake lock
pkl-nix-tools build
pkl-nix-tools run .#hello
pkl-nix-tools develop --command hello-pkl
pkl-nix-tools flake check
```

L'application lit `message.txt` via `../message.txt` depuis le Nix généré.
Nix lit et écrit uniquement le `flake.lock` à la racine de cet exemple.
Vous pouvez supprimer `.pkl-nix-tools/` ; le wrapper le reconstruit.

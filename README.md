# pkl-nix-tools

**Un `flake.pkl` exécutable. Nix fait le reste.** Le shebang appelle un petit
wrapper Bash qui génère `.pkl-nix-tools/flake.nix` avec la dépendance
[`pkl-nix`](https://github.com/Agence-Fluor/pkl-nix) du `PklProject`, puis transmet la
commande à Nix. `flake.lock` reste à la racine du projet.

## Installation

Nix et `curl` sont requis. L'installateur réutilise Pkl s'il est présent ;
sinon, il installe Pkl 0.31.1 pour Linux ou macOS.

```sh
curl -fsSL https://raw.githubusercontent.com/Agence-Fluor/pkl-nix-tools/main/install.sh | sh
```

Ajoutez `~/.local/bin` à votre `PATH` si besoin. [Exemple complet](example/README.md).

## Dans votre projet

`PklProject` référence `pkl-nix` sous l'alias `nix` :

```pkl
amends "pkl:Project"
dependencies {
  ["nix"] {
    uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-nix/pkl-nix@0.1.0"
  }
}
```

Après `pkl project resolve`, commencez `flake.pkl` par :

```pkl
#!/usr/bin/env -S pkl-nix-tools
amends "@nix/Flake.pkl"
```

Puis `chmod +x flake.pkl` et lancez :

```sh
./flake.pkl generate
./flake.pkl build .#hello
./flake.pkl develop
./flake.pkl run .#hello
./flake.pkl flake check
./flake.pkl flake update
```

Le cache `.pkl-nix-tools/` peut être supprimé à tout moment. Aucun `flake.nix`
n'est créé à la racine ; Nix reçoit `path:/projet?dir=.pkl-nix-tools`.

## NixOS

Sur NixOS, l'installateur affiche cette section. Installez les outils via
`configuration.nix`. Placez le dépôt sous `/etc/nixos/pkl-nix-tools` :

```sh
sudo git clone https://github.com/Agence-Fluor/pkl-nix-tools /etc/nixos/pkl-nix-tools
```

Dans la liste `environment.systemPackages` existante, ajoutez :

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

```sh
sudo nixos-rebuild switch
```

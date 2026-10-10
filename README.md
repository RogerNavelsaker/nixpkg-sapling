# nixpkg-sapling

Nix flake packaging for [`@os-eco/sapling-cli`](https://github.com/jayminwest/sapling) v0.3.2.

The default package provides `sapling` and the upstream `sp` alias. It is built from the pinned npm package using Bun2nix, with the CLI version lookup fixed to the pinned package version for standalone execution. The dependency lock is generated with Bun 1.3.13 because Bun2nix 2.1.2 does not accept Bun 1.4's lockfile v2; this does not pin the Bun runtime used by Warren.

```sh
nix build .#default
./result/bin/sapling --version --json
sp_path="$(nix build '.#default^sp' --no-link --print-out-paths)"
"$sp_path/bin/sp" --version --json
```

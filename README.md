# devenv-dagger

Custom [devenv](https://devenv.sh) modules for running a Dagger engine on a Podman machine.

## Usage

> 💡 **Prefer an AI-assisted bootstrap?** This repo ships with a goose skill
> at [`skills/devenv-dagger-init/`](skills/devenv-dagger-init/) that scaffolds
> a working `devenv.yaml` + `devenv.nix` for you.

Add this repository as an input in your project's `devenv.yaml`, along with the
required `upstream-devenv` input. Also add the `imports` section:

```yaml
inputs:
  upstream-devenv:
    url: github:cachix/devenv?dir=src/modules
  dagger-nix:
    url: github:dagger/nix
    inputs:
      nixpkgs:
        follows: nixpkgs
  devenv-dagger:
    url: github:jfroche/devenv-dagger?dir=src/modules
imports:
  - devenv-dagger
```

Notes:

- `upstream-devenv` is required. The devenv-dagger modules import options from it. Omitting it fails evaluation with `error: attribute 'upstream-devenv' missing`.
- `dagger-nix` provides the dagger CLI package. The module reads it with `config.lib.getInput`. Without it, evaluation fails with a message naming the missing input. You can also add it with `devenv inputs add dagger-nix github:dagger/nix --follows nixpkgs`.
- To develop against a local checkout, replace the `devenv-dagger` URL with `path:/absolute/path/to/devenv-dagger?dir=src/modules`.

Then use the module options in your `devenv.nix`:

```nix
{ ... }:
{
  services.dagger.enable = true;
}
```

## Modules

### dagger

Runs a Dagger engine container on the Podman machine as a devenv process with a
readiness probe. Auto-enables `services.podman-machine`. Sets
`_EXPERIMENTAL_DAGGER_RUNNER_HOST` so the dagger CLI talks to the podman-hosted
engine. Provides the `dagger-pull-engine` and `dagger-engine-init` scripts.

```nix
{ ... }:
{
  services.dagger = {
    enable = true;
    # containerName = "devenv-dagger";
  };
}
```

### podman-machine

Manages a Podman machine lifecycle (init, start, stop) as a devenv process.
Usable on its own. Sets `CONTAINER_CONNECTION` in the environment.

```nix
{ ... }:
{
  services.podman-machine = {
    enable = true;
    # machineName = "devenv";
  };
}
```

## Testing

Tests use `devenv-run-tests` from the devenv repository. Each test is a
subdirectory under `tests/` with a `devenv.yaml`, a `devenv.nix`, and an
executable `.test.sh`.

`devenv-run-tests` builds a helper environment from a `flake.lock` in the
current repository. This repo has no flake, so build the environment once and
point `DEVENV_TEST_ENV` at it:

```sh
curl -sL https://raw.githubusercontent.com/cachix/devenv/main/devenv-run-tests/test-env.nix -o /tmp/test-env.nix
nix build --impure --expr 'let pkgs = import (builtins.getFlake "github:cachix/devenv-nixpkgs/rolling") { system = builtins.currentSystem; }; in pkgs.callPackage /tmp/test-env.nix {}' -o ~/.cache/devenv-test-env
export DEVENV_TEST_ENV=$(readlink ~/.cache/devenv-test-env)
```

Run all tests:

```sh
devenv-run-tests run tests
```

Run a single test:

```sh
devenv-run-tests run --only dagger tests
```

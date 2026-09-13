---
name: devenv-dagger-init
description: Initialize a new devenv project with devenv-dagger modules (Dagger engine on a Podman machine)
---

# devenv-dagger devenv initializer

This skill sets up a fresh [devenv](https://devenv.sh) project preconfigured
with the [devenv-dagger](https://github.com/jfroche/devenv-dagger) modules,
reusable devenv modules for running a Dagger engine on a Podman machine.

## Layout

```
devenv-dagger-init/
├── SKILL.md              # this file, always in context when the skill is loaded
├── scripts/
│   └── setup.sh
└── references/
    ├── devenv.yaml.example
    └── devenv.nix.example
```

The agent should keep this `SKILL.md` in context, and load `references/` files
or invoke `scripts/setup.sh` **only when needed**. This keeps the context
window small.

## When to use

Trigger this skill when the user asks to:
- "Create a devenv with devenv-dagger"
- "Bootstrap a Dagger devenv"
- "Set up a Dagger engine on a Podman machine with devenv"

## Prerequisites

Verify before proceeding. Do NOT try to install these silently:
- `command -v devenv`
- `command -v nix`

If either is missing, point the user to https://devenv.sh/getting-started/ and stop.

## Inputs to gather from the user

Ask in a single message:

1. **Target directory**, where to initialize (default: cwd).
   Refuse to overwrite an existing `devenv.nix` unless the user passes
   `--force` (or explicitly confirms).
2. **Which devenv-dagger modules** to enable:
   - `dagger` (default choice, auto-enables `podman-machine`)
   - `podman-machine` alone
3. **Optional name overrides**. `containerName` for the Dagger engine
   container (default `devenv-dagger`) and `machineName` for the Podman
   machine (default `devenv`).
4. **devenv-dagger source**. Default `github:jfroche/devenv-dagger?dir=src/modules`.
   For a local checkout, use `path:/absolute/path?dir=src/modules`.

If the user says "just do it" / "defaults", use the **dagger** module with
default names, from the github source.

## Procedure

### Step 1 - Bootstrap the project skeleton

Run the helper script:

```bash
scripts/setup.sh <target-dir>
```

This will:
- verify prerequisites
- `mkdir -p` the target
- run `devenv init` if `devenv.nix` doesn't exist yet
- run `devenv shell -- true` to lock inputs (skip via `SKIP_EVAL=1`)

Do NOT run the evaluation step yet if you still need to write custom
`devenv.yaml` / `devenv.nix`. Pass `SKIP_EVAL=1` and run `devenv shell -- true`
manually after step 3.

### Step 2 - Write `devenv.yaml`

Load `references/devenv.yaml.example` on demand for the exact shape. Minimal
required content:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  upstream-devenv:                       # REQUIRED, see note below
    url: github:cachix/devenv?dir=src/modules
  dagger-nix:                            # REQUIRED when the dagger module is enabled
    url: github:dagger/nix
    inputs:
      nixpkgs:
        follows: nixpkgs
  devenv-dagger:
    url: github:jfroche/devenv-dagger?dir=src/modules
imports:
  - devenv-dagger
```

> ⚠ devenv-dagger's `top-level.nix` references `inputs.upstream-devenv`. Omitting
> that input fails evaluation with `error: attribute 'upstream-devenv' missing`.
> The dagger module reads the dagger CLI from `inputs.dagger-nix`. Omitting it
> fails evaluation with a message telling you to run
> `devenv inputs add dagger-nix github:dagger/nix --follows nixpkgs`.

### Step 3 - Write `devenv.nix`

Load `references/devenv.nix.example` for a template with both modules listed
(commented). Enable **only** what the user asked for.

Verified module facts (see devenv-dagger README):

- `services.dagger`. Options `enable`, `containerName`. Auto-enables
  `services.podman-machine`. Exports `_EXPERIMENTAL_DAGGER_RUNNER_HOST`.
  Reads the dagger CLI package from a `dagger-nix` input, which must be
  declared in `devenv.yaml`.
- `services.podman-machine`. Options `enable`, `machineName`. Exports
  `CONTAINER_CONNECTION`.

### Step 4 - Evaluate

```bash
cd <target-dir>
devenv shell -- true
```

If this fails, show the error verbatim and stop. Do **not** guess-fix Nix.

### Step 5 - (Optional) start services

Only mention if the user picked at least one module:

```bash
devenv up
devenv processes list
```

## Verification checklist

Before reporting success:

- [ ] `devenv.yaml` has both `upstream-devenv` and `devenv-dagger` inputs, and
      `devenv-dagger` is under `imports:`
- [ ] `devenv.nix` has `enable = true;` only for modules the user selected
- [ ] `devenv shell -- true` exits 0
- [ ] `devenv.lock` exists
- [ ] If dagger is enabled, the `dagger-nix` input is present in `devenv.yaml`
- [ ] If dagger is enabled, `_EXPERIMENTAL_DAGGER_RUNNER_HOST` is set in the
      shell (check with `devenv shell -- printenv _EXPERIMENTAL_DAGGER_RUNNER_HOST`)

## Reporting

Short summary at the end:
- Path of the created project
- Modules enabled
- 2-3 next commands (`devenv up`, `devenv shell`, etc.)

Do NOT dump the generated file contents back unless asked.

## On-demand resources

- `scripts/setup.sh`. Invoke via shell. Do not read into context unless
  debugging its behavior.
- `references/devenv.yaml.example`. Load when you need the yaml template.
- `references/devenv.nix.example`. Load when you need the nix template.

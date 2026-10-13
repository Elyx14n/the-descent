# DragonRuby tests in GitHub Actions

The maintainer confirmed the private-repository workflow works on **2026-10-14**.
The [workflow](../../.github/workflows/ci.yml) is the source of truth for the SDK
repository, archive filename, expected build hash, and job configuration.

## Private SDK provisioning

CI reads the Linux SDK ZIP from the private repository
[`Elyx14n/dragonruby-gtk`](https://github.com/Elyx14n/dragonruby-gtk).
The game repository contains the game's source and development tooling; the SDK
archive stays in the private repository.

The native test job:

1. Checks out the game repository.
2. Checks out the private SDK repository into `dragonruby-tmp` under
   `GITHUB_WORKSPACE`.
3. Extracts `dragonruby-gtk-linux-amd64.zip` from that checkout into
   `$RUNNER_TEMP/dragonruby`.
4. Sets `DRAGONRUBY_HOME` to
   `$RUNNER_TEMP/dragonruby/dragonruby-linux-amd64`.
5. Checks the SDK build and ensures `dragonruby` is executable.
6. Sets up Ruby and Bundler, installs the Linux graphics dependencies, and runs
   `bin/rake test`.

The ZIP must contain a top-level `dragonruby-linux-amd64/` directory, including
`dragonruby` and `VERSION.txt`. Preserve the SDK's hidden `.dragonruby/` directory
as well, particularly for future packaging. The installed SDK's update guide
explicitly includes that hidden directory:
`$DRAGONRUBY_HOME/docs/guides/updating-dragonruby.md`.

Ubuntu runs the Linux SDK. A macOS SDK requires a compatible macOS runner.
Checkout paths must be beneath `GITHUB_WORKSPACE`, so CI stages the archive
there and extracts the SDK into `RUNNER_TEMP`. Checking out the game first avoids
a later game checkout cleaning away the SDK checkout. Sources:
[checkout path validation](https://github.com/actions/checkout/blob/v7/src/input-helper.ts);
[private repository checkout](https://github.com/actions/checkout#checkout-multiple-repos-private).

## GitHub authentication

Create a fine-grained personal access token with:

- **Resource owner:** the account owning the private SDK repository.
- **Repository access:** only the private SDK repository, `dragonruby-gtk`.
- **Repository permissions:** Contents → Read-only.

Store the token in **The Descent's repository Actions secrets** as
`DRAGONRUBY_GTK`. The workflow supplies it to the SDK checkout's `token` input and
uses `persist-credentials: false`. The PAT's repository selection controls which
repository it can read; storing it as a secret controls where the workflow can
use it. Source:
[GitHub PAT configuration](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

If checkout reports `Not Found` from `GET /repos/{owner}/{repo}`, confirm the
repository name, PAT resource owner, selected SDK repository, token validity,
and the value stored in `DRAGONRUBY_GTK`. For organization-owned repositories,
check whether token approval is required. GitHub can return 404 when a private
repository exists but the supplied credential cannot access it. The workflow's
initial secret check only verifies that the value is nonempty. Source:
[GitHub private-resource 404 troubleshooting](https://docs.github.com/en/rest/using-the-rest-api/troubleshooting-the-rest-api#404-not-found-for-an-existing-resource).

## SDK upgrades and packaging

CI compares the `git:` value in the extracted `VERSION.txt` with
`DRAGONRUBY_BUILD` in the workflow. A mismatch fails the job before tests run.
When updating the private ZIP, verify the SDK locally and update the expected
build deliberately. Preserve the archive filename and internal directory layout,
or update the workflow paths at the same time. Keep collaborators on the same
SDK release.

For future packaged builds, keep `dragonruby-publish`, `.dragonruby/`, and the
SDK's support files in the private archive. The installed deployment guide
documents `dragonruby-publish --package mygame` for packaging and
`dragonruby-publish mygame` for packaging and publishing:
`$DRAGONRUBY_HOME/docs/guides/deploying-to-itch.md`. Packaging is not currently a
CI job. The SDK ZIP is neither cached nor uploaded as a workflow artifact.

## Tests and event coverage

Dependency auditing, RuboCop, and native tests run in separate jobs on pushes to
`master`, pull requests, and manual dispatch. Fork pull requests and Dependabot
skip native tests because they cannot access the private SDK secret; audit and
lint still run. Source:
[GitHub secret availability](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#using-secrets-in-a-workflow).

Native tests use the project's [Rake runner](../../lib/dragonruby_tasks.rb) and
[completion report](../../mygame/tests/run.rb). Failed or inconclusive tests,
empty suites, incomplete runs, load failures, and focused runs in CI fail the
task even when the engine returns exit status 0. Linux CI sets headless video,
dummy audio, and software rendering automatically. Native tests exercise runtime
behavior described in [ADR-0005](../adr/0005-render-data-and-room-preview.md#consequences-and-verification);
desktop Ruby alone does not replace this suite.

Earlier local verification used DragonRuby **7.21 Standard**, with **84 tests
passing** via `bin/rake test HEADLESS=1`. That historical result is separate from
the maintainer's confirmation of the working private-repository CI. Automated
tests do not replace manual playtesting.

## Earlier provisioning attempts

The original Butler proposal combined the installed SDK's local update example
in `docs/guides/updating-dragonruby.md` with itch.io's
[Butler CI authentication instructions](https://itch.io/docs/butler/login.html#running-butler-from-ci-builds-github-actions-gitlab-ci-etc).
Those CI instructions describe pushing builds with a Wharf key. The proposal was
a project-specific adaptation, not a documented DragonRuby CI workflow. Butler
fetch returned `invalid game`, including after testing the corrected channel;
the precise server-side cause was not established.

The subsequent itch.io consumer API approach worked with a manually generated
account key, but the uploads available to the maintainer exposed the jam/demo
version. The maintainer chose the private SDK repository to supply the intended
SDK distribution. Neither Butler fetch nor the itch.io consumer API is used by
the current workflow; `BUTLER_API_KEY` and `ITCH_API_KEY` are no longer required
for CI provisioning.

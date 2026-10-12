# DragonRuby tests in GitHub Actions

Research date: **2026-10-12**. Local evidence uses DragonRuby **7.21 Standard**.
These are implementation options, not an accepted CI design or an installed
workflow. SDK paths below are relative to `DRAGONRUBY_HOME`.

## Feasibility and SDK provisioning

The SDK does not need to be committed to this repository. An Actions job can
obtain it before running the project's [Rake tasks](../../Rakefile), or use a
self-hosted runner with the SDK already installed outside the checkout. The
project already launches an external SDK through `DRAGONRUBY_HOME`; see
[setup and native suite commands](../../README.md#first-time-setup-and-running-the-game).

For the installed Standard tier, the SDK's official update guide documents:

```sh
butler fetch dragonruby/dragonruby-gtk:linux-amd64 ./dragonruby-tmp
```

The guide downloads itch.io's butler tool first and authenticates interactively.
For CI, itch.io officially supports supplying `BUTLER_API_KEY` as an environment
variable, using the key obtained through a local `butler login`. Store that key
as a GitHub Actions secret and expose it to the download step. After extraction,
set `DRAGONRUBY_HOME` to the directory containing `dragonruby` and run `bundle exec rake test`.
This combines two documented mechanisms; the actual account's access to the
DragonRuby channel still needs to be verified. Sources: `SDK:
docs/guides/updating-dragonruby.md`, Linux (Standard License);
[itch.io CI authentication](https://itch.io/docs/butler/login.html#running-butler-from-ci-builds-github-actions-gitlab-ci-etc);
[GitHub workflow secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets).

The same SDK guide documents authenticated DragonRuby subscription download
endpoints for Indie and Pro. Those are alternatives for accounts on those tiers;
they are unnecessary for the installed Standard SDK. No official dedicated
DragonRuby setup action was established by this research.

The simple `butler fetch` route selects the channel's latest build. Its source
defines target and output arguments and reads `Channel.Head.ID`; it has no version
selector. To keep the team on the same SDK build, validate the build hash in
`VERSION.txt` and fail if it differs. The installed file records the build date
and Git hash, not the human-readable 7.21 version; that appears in the engine's
startup banner. Exact archive/build pinning needs further investigation, or use a
fixed SDK installation on a self-hosted runner. Source:
[itch.io's fetch implementation](https://github.com/itchio/butler/blob/master/cmd/fetch/fetch.go).

The SDK's project guide distinguishes public runtime redistribution from sharing
the complete development toolkit: it permits including the runtime binary for
running a game, prohibits public commits of the publish/bind tools, and recommends
keeping only game files in public repositories. This is not blanket permission to
publish the whole SDK as a CI artifact or public cache. Keep download credentials
and SDK contents private; this research does not establish additional permission
to redistribute a full SDK or resolve account-specific license terms. Source:
`SDK: docs/guides/starting-a-new-project.md`, Public Repos; `SDK: eula.txt`.

## Native suite and CI failure reporting

The full [native suite](../../mygame/tests/all_test.rb) ran locally with the external
7.21 SDK and all **84 tests passed** using:

```sh
bundle exec rake test HEADLESS=1
```

This verifies local execution without a desktop window. A GitHub-hosted Linux
image still needs its graphics/audio runtime dependencies checked; the local run
does not prove a hosted runner is provisioned correctly. Native tests exercise
DragonRuby APIs and runtime differences recorded in
[ADR-0005](../adr/0005-render-data-and-room-preview.md#consequences-and-verification);
CRuby alone is not a replacement for this suite.

**The engine's exit code alone is insufficient on the installed SDK.** An isolated
temporary test asserting `1 == 2` reported one failed test while the DragonRuby
process returned exit code **0**. A prior test-load failure also exited 0. A CI
runner must turn failed or inconclusive tests, zero executed tests, load errors,
and incomplete runs into a nonzero job status. It must establish positive evidence
that the suite completed successfully. The SDK exposes `passed`, `failed`, and
`inconclusive` arrays in `SDK: docs/oss/dragon/tests.rb`. The project's
[native runner](../../mygame/tests/run.rb) now emits completion counts, and
[Rake](../../lib/dragonruby_tasks.rb) rejects failed, inconclusive, empty, or
incomplete runs and focused tests in CI. Workflow setup should use this task
rather than relying on the engine's exit status.

## Trigger choices and recommendation

A GitHub-hosted Linux job that downloads the SDK privately is the practical first
option for trusted team branches. Keep RuboCop as a separate ordinary Ruby job.
Fork-triggered workflows do not receive download secrets, and Dependabot events
also lack them, so the native job needs an explicit policy for those contributions.
Do not bypass this restriction by checking out untrusted pull-request code in a
privileged `pull_request_target` job. Sources:
[GitHub secrets limitations](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets#using-secrets-in-a-workflow);
[GitHub guidance on untrusted checkout](https://docs.github.com/en/actions/reference/security/secure-use#mitigating-the-risks-of-untrusted-code-checkout).

A self-hosted runner can retain the team's exact external SDK and avoid download
credentials. It adds machine upkeep and must be restricted to trusted code;
GitHub cautions against public-repository self-hosted runners because pull
requests can compromise their persistent environment. Sources:
[self-hosted runner model](https://docs.github.com/en/actions/concepts/runners/self-hosted-runners);
[self-hosted runner security](https://docs.github.com/en/actions/reference/security/secure-use#hardening-for-self-hosted-runners).

Before implementing a workflow, choose hosted download versus self-hosting,
confirm the authorized account's download access, decide how SDK upgrades and
fork contributions are handled, and use the Rake task's native test failure
reporting. No credentials were read or stored, and no workflow was added.

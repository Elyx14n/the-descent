# DragonRuby tests in GitHub Actions

Research date: **2026-10-12**. Local evidence uses DragonRuby **7.21 Standard**.
The [installed workflow](../../.github/workflows/ci.yml) uses GitHub-hosted Linux
runners and private SDK downloads. The initial Butler route failed locally and
in CI with `invalid game` on 2026-10-13. The maintainer subsequently verified that
the consumer upload-list endpoint works with a manually generated account key
and fails with the Wharf key. The workflow now uses that consumer route; archive
download, extraction, and hosted tests still need verification. SDK paths below
are relative to `DRAGONRUBY_HOME`.

## Feasibility and SDK provisioning

The SDK does not need to be committed to this repository. An Actions job can
obtain it before running the project's [Rake tasks](../../Rakefile), or use a
self-hosted runner with the SDK already installed outside the checkout. The
project already launches an external SDK through `DRAGONRUBY_HOME`; see
[setup and native suite commands](../../README.md#first-time-setup-and-running-the-game).

For the installed Standard tier, the SDK's update guide documents:

```sh
butler fetch dragonruby/dragonruby-gtk:linux-amd64 ./dragonruby-tmp
```

That command failed with `itch.io API error (400): /wharf/channels/linux-amd64:
invalid game`. A successful Butler login did not establish download access.
Butler requests the `wharf` OAuth scope, and `fetch` uses Wharf channel/build
endpoints. The cause of the account's download failure remains unverified.
Sources: `SDK: docs/guides/updating-dragonruby.md`, Linux
(Standard License); [Butler authentication](https://github.com/itchio/butler/blob/master/mansion/authenticate.go);
[Butler fetch implementation](https://github.com/itchio/butler/blob/master/cmd/fetch/fetch.go).

Set the GitHub repository secret `ITCH_API_KEY` to the manually generated account
key that passed the upload-list check. A Wharf key from Butler login requests only
`wharf`; it does not request consumer `game:view:uploads` access. Manually generated
account keys are unscoped. Sources:
[Butler authentication](https://github.com/itchio/butler/blob/master/mansion/authenticate.go);
[itch.io authentication and scopes](https://itch.io/docs/api/serverside#scopes).

The workflow lists `/games/404609/uploads`, selects the single `linux-amd64`
upload, then downloads `/uploads/UPLOAD_ID/download` with curl and extracts the
archive outside the checkout. Ruby's standard JSON library parses the upload
list inside the workflow; no separate SDK Rake task is needed. Curl follows HTTPS
redirects without using `--location-trusted`, so authorization is not forwarded
to other hosts. Sources:
[itch.io consumer client](https://github.com/itchio/go-itchio/blob/master/endpoints_uploads.go);
[itch.io download scope](https://itch.io/docs/api/oauth#scopes);
[curl redirect authentication](https://curl.se/docs/manpage.html#-H).

The same SDK guide documents authenticated DragonRuby subscription download
endpoints for Indie and Pro. Those are alternatives for accounts on those tiers;
they are unnecessary for the installed Standard SDK. No official dedicated
DragonRuby setup action was established by this research.

The upload download selects the channel's latest build. To keep the team
on the same SDK build, CI validates the build hash in
`VERSION.txt` and fails if it differs. The installed file records the build date
and Git hash, not the human-readable 7.21 version; that appears in the engine's
startup banner. CI currently requires build
`0c37cf3bb50cff40b47bc6b935bdd106e47aebada` and fails on a different download.
When upgrading, verify the new SDK locally, agree on the team's release, and update
`DRAGONRUBY_BUILD` in the workflow. Exact archive/build pinning needs further
investigation, or use a fixed SDK installation on a self-hosted runner.

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
bin/rake test HEADLESS=1
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

The workflow runs separate lint and native test jobs on pushes, pull requests,
and manual dispatch. Fork pull requests and Dependabot skip the native job; lint
still runs. Native tests use the Rake completion checks and Linux headless mode.
Only the SDK download step receives the `ITCH_API_KEY` secret; the SDK is neither cached
nor uploaded as an artifact. Actions use version tags, and Ruby gems use the
setup action's Bundler cache. The next hosted run must confirm account access, SDK extraction, and
Ubuntu's headless graphics dependencies. No credentials were read or stored in
the repository.

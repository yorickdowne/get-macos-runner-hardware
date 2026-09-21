# get-macos-runner-hardware

What silicon is actually behind GitHub's macOS runner labels? M1 or M4, base or
Pro, how many performance and efficiency cores, how much RAM.

GitHub's macOS runners are VMs, so a single signal can mislead — `hw.model`
usually reports `VirtualMac2,1` no matter what the host is. This repo collects
several independent signals and reports them all.

## How it works

[`.github/workflows/runner-hardware.yml`](.github/workflows/runner-hardware.yml)
runs [`scripts/macos-hardware.sh`](scripts/macos-hardware.sh) on a matrix of
runner labels (currently `macos-latest` and `xcode-27`) and renders one table:

| Runner | Chip | Cores | P+E | Memory | Arch | macOS | hw.model | hw.cpufamily | Image |
|---|---|---|---|---|---|---|---|---|---|
| `macos-latest` | Apple M4 | 10 | 4P+6E | 14.0 GiB | arm64 | 26.0 (25A354) | VirtualMac2,1 | 0x95d9c5e0 | macos26 / 20260901.1 |

*(example row — run it for the real numbers)*

Each runner also gets a collapsed block with the complete `sysctl hw
machdep.cpu` dump, `system_profiler SPHardwareDataType`, and disk space.

`hw.cpufamily` and `hw.cpusubfamily` are stable numeric IDs for the silicon
generation, and `sysctl hw.optional.arm.FEAT_*` (in the raw dump) pins down the
ISA version — both are useful when the brand string is vague inside a VM.

**Where the output goes:**

- **Pull requests** — posted as a comment, upserted so each push updates the
  same comment rather than adding another.
- **Every run, including manual ones** — written to the job summary, visible on
  the run's page in the Actions tab. Run it at will from Actions → *macOS runner
  hardware* → **Run workflow**; manual runs don't comment anywhere.

The comment step is skipped for fork and Dependabot PRs, which only get a
read-only token. Their data is still in the job summary.

## Running it by hand

On any Mac:

```sh
./scripts/macos-hardware.sh /tmp/hw my-laptop
cat /tmp/hw/row-my-laptop.md /tmp/hw/details-my-laptop.md
```

Arguments are the output directory and a label; both are optional.

## Caveat

Results are a snapshot of whatever GitHub happens to be provisioning that day.
Runner images and the hardware behind them change without notice — which is the
reason this runs on every PR.

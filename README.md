# php2shell-linux

A small Bash utility for checking installed Linux PHP packages against published fixes for **CVE-2026-109618** and **CVE-2026-109619** (PHP2Shell), with an optional, confirmed package update on supported Ubuntu releases.

The script reports a simple outcome: **PATCHED**, **UPDATE NEEDED**, or **UNKNOWN**. It is intended for administrators who want a quick **package-level** check, not a full vulnerability scanner.

> **Important:** `PATCHED` means that the recognized, distribution-managed PHP package revisions meet the configured Ubuntu vendor-fix threshold. It does **not** confirm that a running Apache/PHP-FPM worker has reloaded patched code, nor does it assess containers, manually compiled PHP, or other application components.

## Features

- Discover installed PHP packages through the OS package database.
- Compare recognized Ubuntu PHP revisions using `dpkg --compare-versions`.
- Print installed package versions and an easy-to-read assessment result.
- Use `--check` for a read-only assessment (default).
- Use `--apply` on supported Ubuntu releases to update installed PHP packages after interactive confirmation.
- Verify installed package versions again after an attempted update.
- Return distinct exit codes for automation.

## Requirements

- Bash and standard Linux command-line utilities.
- Ubuntu/Debian package assessment requires `dpkg-query`; supported Ubuntu version comparisons also require `dpkg`.
- `--apply` requires root privileges, APT repository access, and an interactive terminal.
- A fixed package must be available from the configured APT repositories. Some older Ubuntu releases require **Ubuntu Pro/ESM**.

## Usage

Clone the repository:

```bash
git clone https://github.com/yuvarajan1989k/php2shell-linux.git
cd php2shell-linux
```

Check syntax and run a read-only assessment:

```bash
bash -n php2shell.sh
bash php2shell.sh --check
echo "Exit code: $?"
```

If the package report is **UPDATE NEEDED**, and this is a test system or an approved maintenance window, you may apply available PHP package updates:

```bash
sudo bash php2shell.sh --apply
echo "Exit code: $?"
```

`--apply` requires typing `APPLY` before refreshing APT metadata or upgrading packages. Package installation scripts may restart services. Take a snapshot/backup and plan application validation first.

**Note:** If you keep the script's filename as `php2shell-v2.1.1-commented.sh` instead of renaming it to `php2shell.sh`, substitute that filename in the commands above.

## Example output

Outdated packages (illustrative Ubuntu 24.04 lab result):

```text
=== PHP2Shell security assessment ===
OS          : Ubuntu 24.04.4 LTS
PHP CLI     : 8.3.6
PHP packages: 4 detected
CVEs        : CVE-2026-109618 / CVE-2026-109619

Vendor fix  : 8.3.6-0ubuntu0.24.04.13
  OLD  php8.3-cli                   8.3.6-0maysync1
  OLD  php8.3-common                8.3.6-0maysync1
  OLD  php8.3-opcache               8.3.6-0maysync1
  OLD  php8.3-readline              8.3.6-0maysync1
RESULT: UPDATE NEEDED — PHP packages below the vendor fix.
```

After patching, the same packages reported `OK` and the result changed to `PATCHED`.

## Results and exit codes

| Result | Exit code | Meaning |
| --- | ---: | --- |
| `PATCHED` | `0` | Recognized installed Ubuntu PHP packages meet the configured fixed revision. |
| `UPDATE NEEDED` | `1` | One or more recognized PHP packages are below the fixed revision. |
| `UNKNOWN` | `2` | The script cannot verify the installed PHP package set against an Ubuntu fix. |
| `ERROR` / incomplete remediation | `3` | Invalid usage, execution failure, unavailable fix during `--apply`, or unsuccessful verification. |

If no distribution-managed PHP packages are detected, the outcome is **UNKNOWN**, not PATCHED.

## Distribution support

The script discovers packages on several Linux families, but **automatic patched/unpatched decisions are currently implemented only for the following Ubuntu releases**:

| Ubuntu release | Recognized PHP family |
| --- | --- |
| 18.04 | PHP 7.2 |
| 20.04 | PHP 7.4 |
| 22.04 | PHP 8.1 |
| 24.04 | PHP 8.3 |
| 26.04 | PHP 8.5 |
| 26.10 | PHP 8.5 |

The fixed package revisions are defined in the script. **Review the latest vendor advisory and package provenance before making remediation decisions**, especially on older ESM releases. This tool does not independently validate repository signing/origin or every third-party packaging scheme.

For Debian, RHEL, Rocky Linux, AlmaLinux, Fedora, Amazon Linux, Alpine, SUSE, and other distributions, package discovery may work but the security verdict is **UNKNOWN** until vendor-specific rules are verified and added. It does not auto-remediate those distributions.

## Safety and limitations

- `--check` only reads local OS/package information; it does not refresh repository metadata, install updates, or restart services.
- `--apply` refreshes APT metadata and upgrades the detected PHP packages only after explicit confirmation. Package maintainer scripts or system services may restart automatically.
- A package version comparison alone does not prove that running workers are using newly installed code. After maintenance, check Apache/PHP-FPM and validate application behavior.
- Docker/Podman images, source builds, alternate PHP installations, and third-party PHP packages are not fully assessed.
- Some older Ubuntu versions require Ubuntu Pro/ESM to make a vendor-fixed revision available. If a suitable candidate is not available, `--apply` stops rather than claiming success.
- The script does not replace vendor advisories, CVE inventory, or a security vulnerability management platform.

## Testing performed

| Environment / scenario | Observation |
| --- | --- |
| Ubuntu 24.04, patched PHP 8.3 | Latest commented script `--check` returned `PATCHED`, exit `0`. |
| Ubuntu 24.04, older PHP 8.3 packages | Earlier simplified script identified packages below the fixed revision. |
| Ubuntu 24.04, PHP upgrade | Earlier simplified script upgraded four PHP packages and follow-up assessment reported `PATCHED`. |
| Ubuntu 18.04, PHP 7.2 | Earlier script reported `BELOW_VENDOR_FIX` on an older package revision; no production remediation was attempted. |
| Final commented script, `--apply` | **Not yet live-tested** in the reported lab. |
| Other Linux distributions | Broader compatibility and remediation testing pending. |

Do not interpret the above as a claim of full distribution coverage or production certification.

## References

- [Canonical — PHP2Shell vulnerability fixes available](https://ubuntu.com/blog/php2shell-vulnerability-fixes-available)
- [Ubuntu Pro / Expanded Security Maintenance](https://ubuntu.com/security/esm)

## Contributing

Issues and pull requests are welcome. Please include the distribution, release, PHP package names and versions, relevant vendor advisory, and a sanitized sample of the output. **Never post access tokens, credentials, customer hostnames, or internal IPs.**

## License

This project is licensed under the MIT License.

You are free to use, modify, and distribute this script, including for commercial purposes, provided that the original copyright and license notice are retained.

See the LICENSE file for the full license terms.

Copyright (c) 2026 Yuvarajan Kandasamy.

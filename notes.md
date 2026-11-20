# Configuration Notes

`ap/` configures a personal HTCondor Access Point on a host on a Tailscale tailnet. EPs are
contributed through `htcondor annex create`'s tarball and connect to the AP over the tailnet,
without root on the EP. The AP is based on `bin/make-ap-from-tarball` from the non-root HTCondor
installation instructions. The EP is based on the configuration in the annex tarball.

The EP-to-AP transport (local forwarder, `TCP_FORWARDING_HOST`, CCB) is described in
`backlog/decisions/decision-1`.

# AP Configuration

## Daemon Name Pinning

By default, AP daemon names are derived from the `FULL_HOSTNAME` of the host the AP runs on. To keep
AP daemon names and IDToken trust domains consistent if the AP is resumed on a different host, we set
the following explicitly:

* `TRUST_DOMAIN`: Subject domain of IDTokens that the AP accepts
* `ANNEX_TOKEN_DOMAIN`: EP subject domain checked in the start expressions of annex jobs.
* `SCHEDD_NAME`: Name of the AP's schedd. Used by annex EPs to locate the schedd for direct attach.

## Force IDToken Auth

Annex jobs' start expression requires that an EP have an `AuthenticatedIdentity` matching
`<submitter>@<annex token domain>`. An EP on the same host as its AP may otherwise attempt FS auth
and get an incorrect identity. We force IDToken auth from the EP to the AP:

```
AP_COLLECTOR.SEC_DEFAULT_AUTHENTICATION_METHODS = IDTOKENS
SCHEDD.SEC_DEFAULT_AUTHENTICATION_METHODS = IDTOKENS
```

We also grant DAEMON permissions to the IDToken's custom subject to allow schedd direct attach
and CCB registration, since it's not allowed for this subject by default:

```
AP_COLLECTOR.ALLOW_DAEMON = $(ALLOW_DAEMON), ...
SCHEDD.ALLOW_DAEMON = $(ALLOW_DAEMON), ...
```

# EP Configuration

## Explicit IDToken Creation

The `annex.token` that `htcondor annex create` puts in the tarball (via `condor_token_fetch`) does
not authorize an EP in this setup: its subject is `condor@password` rather than
`<submitter>@<annex token domain>`, and it expires after 60 seconds. The AP mints the EP token itself:

```
IDENTITY="$(whoami)@$(condor_config_val ANNEX_TOKEN_DOMAIN)"
condor_token_create -key AP -identity "$IDENTITY" \
    -authz READ -authz WRITE -authz ADVERTISE_STARTD -authz ADVERTISE_MASTER -authz DAEMON
```

# Development

Shell scripts are checked by prek hooks (`.pre-commit-config.yaml`): shellcheck, shfmt, and
file hygiene. Run `prek install` once per clone, and `prek run --all-files` before committing.

Hook revs are pinned to commit SHAs. Update them only to releases at least a week old:

```
prek update --cooldown-days 7 --freeze
```

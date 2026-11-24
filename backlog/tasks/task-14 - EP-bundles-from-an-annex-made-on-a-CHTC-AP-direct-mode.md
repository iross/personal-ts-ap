---
id: TASK-14
title: EP bundles from an annex made on a CHTC AP (direct mode)
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-20 16:26'
updated_date: '2026-11-24 21:39'
labels:
  - ep
  - chtc
dependencies: []
references:
  - >-
    https://github.com/htcondor/htcondor/blob/v25.15.15/src/condor_tools/htcondor_cli/annex_create.py
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Let a user attach EPs to a CHTC access point (e.g. ap2001) as an HTCondor annex, using this repo's EP launcher, when the EP host has outbound internet access to CHTC. An annex brings its own tokens, so CHTC needs no per-EP credentials. CHTC asks users to contact chtc@cs.wisc.edu before using annexes; staff don't need that approval, but the README should still say it for everyone else.

The user runs 'htcondor annex create --idle-time N NAME' on the CHTC AP (no target machine, which writes annex-NAME.tar), copies the tarball to the EP host, and runs run-ep.sh with it (no bundle). The EP needs no Tailscale in this mode: the annex connects directly to the AP and to the annex collector configured on that AP.

Verified 2026-11-20: ap2001 has annex support. Its ANNEX_COLLECTOR is ap2002.chtc.wisc.edu:9618?sock=ap_collector (the collector on ap2002, not htcondor-cm-hpcannex.osgdev.chtc.io). The tarball carries this, so the bundle shouldn't hard-code a collector.

Changes:
- ep/run-ep.sh, ep/docker-ep.sh: take annex-NAME.tar as an argument (direct mode); without one, run the personal bundle they're unpacked from (make-ep-bundle.sh stays personal-only).
- ep/run-ep.sh: in direct mode skip fetch_tailscale/join_tailnet/start_forwarder and the annex-ep.token override (a workaround for the personal AP; a CHTC AP's annex.token is used as issued). TS_AUTHKEY required only when the mode uses Tailscale, here and in ep/docker-ep.sh.
- README: 'Annex to a CHTC AP' section (contact facilitators, annex create on the AP, run-ep.sh/docker-ep.sh with the tarball, jobs need MY.TargetAnnexName = "NAME" and MY.WantFlocking = true).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A job with MY.TargetAnnexName/MY.WantFlocking submitted on the CHTC AP runs on the EP; stopping the EP withdraws it
- [ ] #2 Personal-AP bundles behave exactly as before
- [x] #3 README documents the CHTC annex workflow, including contacting facilitators
- [ ] #4 run-ep.sh annex-NAME.tar (and docker-ep.sh) runs an annex made on a CHTC AP, with no bundle
- [x] #5 Direct mode needs no TS_AUTHKEY or Tailscale
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. make-ep-bundle.sh: --annex-tar builds an EP_MODE=direct bundle (run-ep.sh, docker-ep.sh, annex tarball, ep.env); default stays EP_MODE=personal.
2. run-ep.sh: require EP_MODE; Tailscale, forwarder, port check, python3 and the annex-ep.token override only in personal mode.
3. docker-ep.sh: read ep.env; require TS_AUTHKEY only in personal mode.
4. README 'Annex to a CHTC AP' section; notes.md direct-mode paragraph.
5. Test locally with a stand-in tarball, then end-to-end against ap2001.
6. (User request, replaces step 1) No bundle for direct mode: run-ep.sh and docker-ep.sh take annex-NAME.tar as an argument; without one they run the personal bundle they're unpacked from. make-ep-bundle.sh goes back to personal-only, ep.env without EP_MODE. The work directory goes next to the annex tarball.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented steps 1-4. Checked against htcondor v25.15.15 annex_create.py: on a CHTC AP the tarball's annex.token is fetched with -key hpcannex-key as NAME.<user>@<ANNEX_TOKEN_DOMAIN>, lifetime ANNEX_TOKEN_LIFETIME (default 90 days), so it is used as issued. annex create refuses without a job targeting the annex (unless HPC_ANNEX_REQUIRE_JOB=false), so the README says to submit first. CHTC's chtc-scaling-beyond-chtc skill confirms MY.TargetAnnexName + MY.WantFlocking, and adds requirements = (Target.AnnexName == NAME) to keep jobs off CHTC capacity.

Local tests (macOS + Docker, AlmaLinux 9 aarch64): direct bundle built from the personal AP's annex tarball (same layout); docker-ep.sh ran it with TS_AUTHKEY unset: annex setup, HTCondor started, no tailscaled/forwarder, annex.token unchanged from the tarball, docker stop shut it down gracefully. Errors checked: renamed tarball, name/content mismatch, missing file, non-tar, missing --annex-tar arg, no AP for personal mode, personal bundle without TS_AUTHKEY (run-ep.sh and docker-ep.sh), ep.env without EP_MODE.

Not yet tested: a real CHTC annex end to end (AC 3); a personal bundle end to end against the tailnet AP (AC 4; only its guards were exercised).

Live test (user's CHTC AP, annex collector on ap2002): a direct-mode EP outside wisc.edu connects, but jobs don't match. The AP's JOB_TRANSFORM_REQUIREMENTS (JobUniverse == 5) prepends a pool restriction picked by the flock/glide flags: none -> PoolName == "CHTC" (or gzk* for GPU jobs); want_campus_pools/WantFlocking only -> Machine ends in .wisc.edu && !OSPool; want_ospool/WantGlidein only -> CHTC || OSPool. So the documented TargetAnnexName + WantFlocking recipe only matches annex EPs named *.wisc.edu. Workaround to test: WantFlocking + WantGlidein (no branch seen for both) plus requirements = (Target.AnnexName == NAME). Proper fix is AP-side: skip that transform for TargetAnnexName jobs. Update the README's submit lines once the working combination is confirmed.

Container jobs (HasContainer/HasDockerURL) don't match on node17: Ubuntu AppArmor userns restriction blocks the bundled apptainer and there is no system apptainer. Not a direct-mode issue; tracked as a separate task (warn in run-ep.sh + README).

Confirmed by the user: MY.WantFlocking = true + MY.WantGlidein = true removes the AP's .wisc.edu requirement. README submit lines updated to that combination.

Found on node17: run-ep.sh died on SIGHUP (backgrounded, then the session closed) without cleanup, leaving condor_master/startd running in their own session. Fixed: trap HUP like INT/TERM, and cleanup runs with set +e so a failed write to a dead terminal can't abort it. Tested in Docker: HUP to run-ep.sh stops all HTCondor processes and the pilot cleans up.

GPU jobs on the CHTC annex: the AP's transforms give request_gpus jobs GPU Lab ConcurrencyLimits (e.g. GPULAB_MEDIUM.<user>:1). With them, ap2002's schedd logs 'No job found to run on slot1@...' for the direct-attached slot every ~5 s and never starts the job; condor_qedit <job> ConcurrencyLimits undefined made it start (confirmed by the user). README documents the qedit workaround. Note: -better-analyze against the annex collector is misleading for annex slots: their collector ad has Start = "Directly attached to schedd ..." (a string), so every job shows as rejected by the slot; the schedd's SchedLog and the EP's StartLog are the useful places to look.

AP-side fixes to raise with CHTC (both would make the documented annex recipe work unmodified): the REQUIREMENTS transform should skip TargetAnnexName jobs (avoids needing WantGlidein), and the GPU Lab / concurrency transforms should skip them too.

GPU job 9064666 runs on node17's annex EP (GPU-0c932e23 assigned via CUDA_VISIBLE_DEVICES, system apptainer). Startup cost per job on node17: ~18 min for its 11.9 GB input over cedar (~10.6 MB/s) plus ~25 min for apptainer to pull the 11.2 GB arm64 docker:// image (~11 MB/s) into the job's own scratch/cache and build a SIF; the cache is deleted with the job, so every job repeats it. Both rates suggest node17's path to UW is the limit. Workload-side fix (not a bundle change): prebuilt SIF on node17 with transfer_container = false, data bound in via --config SINGULARITY_BIND_EXPR.

Step 6 done (user asked to drop the bundle step for direct mode): run-ep.sh/docker-ep.sh take annex-NAME.tar as an argument; tarball validation moved from make-ep-bundle.sh into run-ep.sh; make-ep-bundle.sh restored to HEAD (personal-only, ep.env without EP_MODE); work dir is created next to the annex tarball (unchanged for personal bundles, where the tarball is in htc-ep/). README/notes updated. Tested in Docker with a stand-in tarball: error cases (no arg and no ep.env, missing, renamed, non-tar, two tarballs, unknown option, personal bundle without TS_AUTHKEY); docker-ep.sh with the tarball in another directory and in the script's own directory (no duplicate mount); --config applied; no tailscaled/forwarder; docker stop shuts the annex down. Not yet run with a real CHTC tarball in this form (AC 4).
<!-- SECTION:NOTES:END -->

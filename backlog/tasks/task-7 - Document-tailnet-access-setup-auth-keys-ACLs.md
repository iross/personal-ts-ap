---
id: TASK-7
title: 'Document tailnet access setup (auth keys, ACLs)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 02:48'
labels:
  - docs
  - networking
dependencies:
  - TASK-6
references:
  - 'https://tailscale.com/kb/1111/ephemeral-nodes'
  - 'https://tailscale.com/kb/1085/auth-keys'
  - 'https://app.todoist.com/app/task/6j3gCvMMxjMp278v'
priority: medium
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document: ephemeral, pre-approved, tagged auth keys (tag:htcondor-ep) for EPs; an ACL/grants snippet allowing tag:htcondor-ep -> AP:9618 only; how the AP node is tagged/owned.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 ACL snippet tested against a real tailnet
- [x] #2 Docs explain key lifetime and revocation
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Docs written in README 'Tailnet access: keys and policy': ephemeral/reusable/pre-approved/tagged keys, key expiry (1-90 days), revocation (does not disconnect running EPs), ephemeral removal (logout on exit; 30-60 min after a crash), grants snippet with tagOwners/hosts/grants/tests. Syntax checked against tailscale.com/kb/1337 (policy syntax), 1324 (grants), 1085 (auth keys), 1111 (ephemeral nodes). AC1 (test on a real tailnet) deferred by the user: needs the tail934bf policy edited and a tag:htcondor-ep key.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-11-20 02:48
---
AC1 deferred by user (2026-11-20): live policy test needs the tailnet policy edited; leaving the task In Progress until then.
---
<!-- COMMENTS:END -->

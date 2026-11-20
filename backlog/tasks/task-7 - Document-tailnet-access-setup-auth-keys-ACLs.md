---
id: TASK-7
title: 'Document tailnet access setup (auth keys, ACLs)'
status: To Do
assignee: []
created_date: '2026-11-19 21:50'
labels:
  - docs
  - networking
dependencies:
  - TASK-6
references:
  - 'https://tailscale.com/kb/1111/ephemeral-nodes'
  - 'https://tailscale.com/kb/1085/auth-keys'
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
- [ ] #2 Docs explain key lifetime and revocation
<!-- AC:END -->

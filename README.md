# Personal HTCondor AP over Tailscale

A single-user HTCondor Access Point (AP) on a host on your Tailscale tailnet, with Execution
Points (EPs) contributed from any Linux machine you can join to the tailnet, without root on the EP.

The intended workflow:

1. Start an AP on a host that is on your tailnet (`ap/install.sh`, then `ap/start.sh`).
2. Build an EP bundle (annex tarball) on the AP.
3. Copy the bundle to the to-be-EP and join it to the tailnet.
4. Run the EP; it registers with the AP and runs your queued jobs.

This is a work in progress; steps 2–4 are not scripted yet. See `notes.md` for configuration
details and `backlog/` for the plan.

Example jobs are in `examples/` (`hello_world`, and a multi-stage DAG in `dag_plot`).

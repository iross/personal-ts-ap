#!/usr/bin/env python3
"""Forward local TCP connections to the AP through an unprivileged tailscaled.

Usage: forward.py LISTEN_PORT TARGET_HOST TARGET_PORT TAILSCALE_CMD...

Listens on 127.0.0.1:LISTEN_PORT. Each accepted connection is piped through
`TAILSCALE_CMD nc TARGET_HOST TARGET_PORT`, so HTCondor on a host without a
tailnet route can reach the AP. Written for Python 3.6+ (EL8's python3).
"""

import asyncio
import sys

CHUNK = 65536


async def pump(reader, writer):
    """Copy reader to writer until EOF, then close the writer."""
    try:
        while True:
            data = await reader.read(CHUNK)
            if not data:
                break
            writer.write(data)
            await writer.drain()
    except (ConnectionError, BrokenPipeError):
        pass
    finally:
        writer.close()


def make_handler(nc_cmd):
    async def handle(client_reader, client_writer):
        proc = await asyncio.create_subprocess_exec(
            *nc_cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
        )
        await asyncio.gather(
            pump(client_reader, proc.stdin),
            pump(proc.stdout, client_writer),
        )
        if proc.returncode is None:
            proc.terminate()
        await proc.wait()

    return handle


def main(argv):
    if len(argv) < 5:
        print(__doc__, file=sys.stderr)
        return 2
    listen_port, target_host, target_port = int(argv[1]), argv[2], argv[3]
    nc_cmd = argv[4:] + ["nc", target_host, target_port]

    # Python 3.14 no longer creates a loop implicitly in get_event_loop().
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        server = loop.run_until_complete(
            asyncio.start_server(make_handler(nc_cmd), "127.0.0.1", listen_port)
        )
    except OSError as e:
        print(f"forward.py: cannot listen on 127.0.0.1:{listen_port}: {e}", file=sys.stderr)
        return 1
    print(f"forward.py: 127.0.0.1:{listen_port} -> {target_host}:{target_port}", flush=True)
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

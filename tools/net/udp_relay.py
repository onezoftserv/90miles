"""UDP relay for the intent link probe (game/tests/manual/intent_link_probe.tscn, OpenSpec change
intent-delivery): per-direction delay, jitter, loss and optional reordering between a client and a
host on this machine. Manual only, never in CI.

usage: python -I tools/net/udp_relay.py <listen_port> <target_port> <delay_ms> <jitter_ms> <loss_pct> <seconds> [reorder_pct]
The client joins <listen_port>; the host listens on <target_port>, for example 7788 and 7789.
Each packet waits delay + uniform(0, jitter) ms. Packets leave in the order they came (FIFO, ties
broken by arrival order), except that reorder_pct of them are held 20 to 50 ms past their turn, so
later packets overtake them. loss_pct of them are dropped. Quits after <seconds> and prints
what it counted.
"""
import asyncio, collections, random, sys

listen_port, target_port = int(sys.argv[1]), int(sys.argv[2])
delay, jitter, loss = float(sys.argv[3]) / 1000, float(sys.argv[4]) / 1000, float(sys.argv[5]) / 100
seconds = float(sys.argv[6])
reorder = float(sys.argv[7]) / 100 if len(sys.argv) > 7 else 0.0
stats = collections.Counter()


class Lane:
    """One direction: a FIFO with a single timer, so equal due times never swap."""

    def __init__(self, loop, name, send):
        self.loop, self.name, self.send = loop, name, send
        self.queue = collections.deque()  # (due, data)
        self.last_due = 0.0
        self.timer = None

    def push(self, data):
        stats[self.name] += 1
        if random.random() < loss:
            stats[self.name + "_drop"] += 1
            return
        due = max(self.last_due, self.loop.time() + delay + random.uniform(0, jitter))
        self.last_due = due
        if reorder and random.random() < reorder:
            stats[self.name + "_late"] += 1
            self.loop.call_at(due + random.uniform(0.02, 0.05), self.send, data)
            return
        self.queue.append((due, data))
        self._arm()

    def _arm(self):
        if self.timer is None and self.queue:
            self.timer = self.loop.call_at(self.queue[0][0], self._fire)

    def _fire(self):
        self.timer = None
        now = self.loop.time()
        while self.queue and self.queue[0][0] <= now:
            self.send(self.queue.popleft()[1])
        self._arm()


class Down(asyncio.DatagramProtocol):
    def __init__(self, relay, client_addr):
        self.lane = Lane(relay.loop, "down", lambda d: relay.transport.sendto(d, client_addr))

    def datagram_received(self, data, addr):
        self.lane.push(data)


class Relay(asyncio.DatagramProtocol):
    def __init__(self, loop):
        self.loop, self.clients = loop, {}

    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        client = self.clients.get(addr)
        if client is None:
            client = {"pending": [data], "lane": None}
            self.clients[addr] = client
            fut = asyncio.ensure_future(self.loop.create_datagram_endpoint(
                lambda: Down(self, addr), remote_addr=("127.0.0.1", target_port)))
            def ready(f, client=client):
                transport = f.result()[0]
                client["lane"] = Lane(self.loop, "up", transport.sendto)
                for d in client.pop("pending"):
                    client["lane"].push(d)
            fut.add_done_callback(ready)
        elif client["lane"] is None:
            client["pending"].append(data)
        else:
            client["lane"].push(data)


async def main():
    loop = asyncio.get_running_loop()
    await loop.create_datagram_endpoint(lambda: Relay(loop), local_addr=("127.0.0.1", listen_port))
    await asyncio.sleep(seconds)
    print("RELAY", dict(stats), flush=True)

asyncio.run(main())

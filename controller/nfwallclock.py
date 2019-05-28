import time

import attr
from twisted.internet import task

UPDATE_FREQUENCY = 0.1  # seconds

@attr.s
class NFWallClock:
    p4switch  = attr.ib()
    forced_time = attr.ib(default=None)

    def start(self):
        self.loop = task.LoopingCall(self.write_time)
        self.loop.start(UPDATE_FREQUENCY)

    def write_time(self):
        now = self.forced_time if self.forced_time else int(time.time())
        self.p4switch.reg_write('wall_clock', 0, now)

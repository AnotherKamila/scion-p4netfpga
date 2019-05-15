import time

from twisted.internet import task

from .base_controller import BaseController

UPDATE_FREQUENCY = 1  # seconds

class NFWallClock(BaseController):
    def init(self):
        self._forced_time = None
        self.loop = task.LoopingCall(self.write_time)
        self.loop.start(UPDATE_FREQUENCY)

    def write_time(self):
        now = self._forced_time if self._forced_time else int(time.time())
        self.p4switch.reg_write('wall_clock', 0, now)

    def force_time(self, t):
        self._forced_time = t

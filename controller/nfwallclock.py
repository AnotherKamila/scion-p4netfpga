from twisted.internet import task

from .base_controller import BaseController

UPDATE_FREQUENCY = 1  # seconds

class NFWallClock(BaseController):
    def init(self):
        self.loop = task.LoopingCall(self.write_time)
        self.loop.start(UPDATE_FREQUENCY)

    def write_time(self):
        print('hi, wall clock is a TODO')
        self.p4switch.reg_write('wall_clock', 0, 247)

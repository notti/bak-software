import select
import os
import smmap

base = '/sys/devices/plb@0/84000000.proc2fpga/'

class csvit:
    def __init__(self, mem):
        self.mem = mem
        if self.mem.mem == 'emce1':
            self.m = int(self.mem.hardware['core/n'])
        else:
            self.m = int(self.mem.hardware['depth'])
        self.pos = 0
        if self.mem.mem == 'emce0':
            self.next = self.readreal
        else:
            self.next = self.readcomplex
            self.m *= 2
    def __iter__(self):
        return self
    def readcomplex(self):
        if self.pos == self.m:
            raise StopIteration
        im, re = self.mem.data[self.pos:self.pos+2]
        self.pos += 2
        return "%s, %s\n" % (re, im)

    def readreal(self):
        if self.pos == self.m:
            raise StopIteration
        re = self.mem.data[self.pos]
        self.pos += 1
        return "%s\n" % re

class memory:
    def __init__(self, hardware, mem, mode):
        self.hardware = hardware
        self.mem = mem
        if mode == 'r':
            mode = 'r'
            access = smmap.ACCESS_READ
        else:
            mode = 'r+'
            access = smmap.ACCESS_WRITE
        if mem == 'emce1':
            length = 4096*2
        else:
            length = 49152*2
        f = open('/dev/'+mem, mode)
        self.data = smmap.mmap(f.fileno(), length, 'h', access)
        f.close()
        self.pos = 0
        if mem == 'emce0':
            self.write = self.writereal
        else:
            self.write = self.writecomplex

    def writereal(self, real, imag):
        self.data[self.pos] = real
        self.pos += 1

    def writecomplex(self, real, imag):
        self.data[self.pos:self.pos+2] = imag, real
        self.pos += 2

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.data.close()

    def __iter__(self):
        return csvit(self)


class hardware:
    values = ['gtx0/data_valid', 'gtx0/descramble', 'gtx0/enable', 'gtx0/polarity', 'gtx0/rxeqmix',
              'gtx1/data_valid', 'gtx1/descramble', 'gtx1/enable', 'gtx1/polarity', 'gtx1/rxeqmix',
              'average/active', 'average/err', 'average/width',
              'core/L', 'core/circular', 'core/iq', 'core/n', 'core/ov_fft', 'core/ov_ifft', 'core/ov_cmul',
              'core/scale_sch0',
              'core/scale_sch1',
              'core/scale_sch2',
              'core/scale_sch3',
              'core/scale_sch4',
              'core/scale_sch5',
              'core/scale_schi0',
              'core/scale_schi1',
              'core/scale_schi2',
              'core/scale_schi3',
              'core/scale_schi4',
              'core/scale_schi5',
              'core/scale_cmul', 'core/start',
              'auto/run',
              'receiver/input_select', 'receiver/stream_valid',
              'transmitter/dc_balance', 'transmitter/frame_offset', 'transmitter/muli', 'transmitter/mulq', 'transmitter/toggle', 'transmitter/shift', 'transmitter/ovfl', 'transmitter/sat',
              'trigger/arm', 'trigger/type',
              'depth']

    def __call__(self, mem, mode):
        return memory(self, mem, mode)

    def __getitem__(self, key):
        with open(base + key, 'r') as f:
            return f.read().rstrip()

    def __setitem__(self, key, value):
        with open(base + key, 'w') as f:
            f.write(value)

    def __iter__(self):
        return self.values.__iter__()

    def __init__(self):
        self._poller = select.poll()
        self._desc = {}
        for name in os.listdir(base+'int'):
            f = open("%sint/%s" % (base, name),'r')
            self._desc[f.fileno()] = (f, name)
            f.read()
            self._poller.register(f, select.POLLPRI | select.POLLERR)


    def check(self):
        l = self._poller.poll(2000)
        ret = []
        for fd, event in l:
            f, name = self._desc[fd]
            f.seek(0)
            f.read()
            ret.append(name)
        return ret



import struct
import select
import os

base = '/sys/devices/plb.0/84000000.proc2fpga/'

class csvit:
    def __init__(self, mem):
        self.mem = mem
        if self.mem.mem == 'emce1':
            self.m = int(self.mem.hardware['core/n'])
        else:
            self.m = int(self.mem.hardware['depth'])
        if self.mem.mem == 'emce0':
            self.unpacker = struct.Struct('h')
            self.next = self.readreal
        else:
            self.unpacker = struct.Struct('hh')
            self.next = self.readcomplex
    def __iter__(self):
        return self
    def readcomplex(self):
        self.m -= 1
        if self.m < 0 :
            raise StopIteration
        im, re = self.unpacker.unpack(self.mem.f.read(4))
        return "%s, %s\n" % (re, im)

    def readreal(self):
        self.m -= 1
        if self.m < 0 :
            raise StopIteration
        return "%s\n" % self.unpacker.unpack(self.mem.f.read(2))

class memory:
    def __init__(self, hardware, mem, mode):
        self.hardware = hardware
        self.mem = mem
        with open(base + 'req', 'w') as f:
            f.write("1\n")
        with open(base + 'req', 'r') as f:
            while not int(f.read()):
                f.seek(0)
        self.f = open('/dev/'+mem, mode + 'b')
        if mem == 'emce0':
            self.write = self.writereal
            self.packer = struct.Struct('h')
        else:
            self.write = self.writecomplex
            self.packer = struct.Struct('hh')

    def writereal(self, real, imag):
        self.f.write(self.packer.pack(real))

    def writecomplex(self, real, imag):
        self.f.write(self.packer.pack(imag, real))

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.f.close()
        with open(base + 'req', 'w') as f:
            f.write("0\n")

    def __iter__(self):
        return csvit(self)


class hardware:
    values = ['gtx0/data_valid', 'gtx0/descramble', 'gtx0/enable', 'gtx0/polarity', 'gtx0/rxeqmix',
              'gtx1/data_valid', 'gtx1/descramble', 'gtx1/enable', 'gtx1/polarity', 'gtx1/rxeqmix',
              'gtx2/data_valid', 'gtx2/descramble', 'gtx2/enable', 'gtx2/polarity', 'gtx2/rxeqmix',
              'average/active', 'average/err', 'average/width',
              'core/L', 'core/circular', 'core/iq', 'core/n', 'core/ov_fft', 'core/ov_ifft', 'core/scale_sch', 'core/scale_schi', 'core/start',
              'receiver/input_select', 'receiver/stream_valid',
              'transmitter/dc_balance', 'transmitter/frame_offset', 'transmitter/muli', 'transmitter/mulq', 'transmitter/toggle',
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



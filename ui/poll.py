#!/usr/bin/python

import select, sys

base = '/sys/devices/plb.0/84000000.proc2fpga'

def setup(poller, base):
    ints = {}
    for name in os.listdir("%s/int" % (base,)):
        f = open("%s/int/%s" % (base, name), 'r')
        ints[f.fileno()] = (name, f)
        poller.register(f, select.POLLERR | select.POLLPRI)
    poller.register(sys.stdin, select.POLLIN | select.POLLPRI)
    return ints

def reset(ints, fds = None):
    if fds == None:
        fds = ints.keys()
    for f in fds:
        ints[f].seek(0)
        ints[f].read()

def poll(ints, poller):
    events = poller.poll()
    fds = []
    for fd, event in events:
        if fd == 0:
            return (,)
        print ints[fd][0]
        fds.append(fd)
    return fds

def main():
    poller = select.poll()
    ints = setup(poller, base)
    reset(ints)
    while True:
        fds = poll(ints, poller)
        if fds == 0:
            break
        reset(ints, fds)
    for fd in ints.keys():
        poller.unregister(fd)
        ints[fd][1].close()

main()

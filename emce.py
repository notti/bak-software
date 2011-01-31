#!/usr/bin/python

import select, threading

def do_poll():
    while 1:
        f = open('/sys/devices/plb.0/84000000.iotest/intr','r')
        f.read()
        p = select.poll()
        p.register(f,select.POLLERR | select.POLLPRI)
        p.poll()
        p.unregister(f)
        f.close()
        print 'fired!'

def do_led(led):
    led=str(led)
    state = 0
    while 1:
        f = open('/sys/devices/plb.0/84000000.iotest/leds/'+led,'w')
        f.write(str(state));
        f.close()
        f = open('/sys/devices/plb.0/84000000.iotest/leds/'+led,'r')
        new = f.read(1);
        if new != str(state):
            print 'wrong'
        f.close()
        state=(state+1)%2;

for i in range(0,8):
    t = threading.Thread(target=do_led,args=(i,))
    t.start()
t = threading.Thread(target=do_poll)
t.start()


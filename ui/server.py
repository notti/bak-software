#!/usr/bin/python
from twisted.application import internet, service
from twisted.web import static, server, resource
from twisted.internet import protocol, threads, reactor, defer
from twisted.protocols.basic import LineReceiver
from txws import WebSocketFactory
import emce
import json
import csv
import mmap

hardware = emce.hardware()

class MonitorProtocol(protocol.Protocol):
    def __init__(self, factory):
        self.factory = factory
    def connectionMade(self):
        self.factory.clients.add(self)
        for setting in hardware:
            self.send(cmd = 'update', target = setting, value = hardware[setting])
    def connectionLost(self, reason):
        self.factory.clients.remove(self)
    def dataReceived(self, data):
        data = json.loads(data)
        if data['cmd'] == 'set':
            hardware[data['target']] = data['value']
            self.send(**data)
        elif data['cmd'] == 'do':
            hardware[data['target']] = "1"
            self.send(**data)
        elif data['cmd'] == 'get':
            self.send(cmd = 'set', target = data['target'], value = hardware[data['target']])
    def send(self, **kwargs):
        self.transport.write(json.dumps(kwargs))

class MonitorFactory(protocol.Factory):
    def __init__(self):
        self.clients = set()
    def buildProtocol(self, addr):
        return MonitorProtocol(self)

class Data(resource.Resource):
    isLeaf = True
    def render_GET(self, request):
        def putfile(request):
            with hardware(request.postpath[0], 'r') as f:
                reactor.callFromThread(request.write, ''.join(f))
        def done(x):
            request.finish()
        if not len(request.postpath) or request.postpath[0] not in ('emce0', 'emce1', 'emce2', 'emce3'):
            request.setResponseCode(404)
            return 'Not Found'
        request.setHeader("content-disposition" ,"attachment;filename=mem.csv")
        request.setHeader("content-type" ,"text/csv")
        threads.deferToThread(putfile, request).addCallback(done)
        return server.NOT_DONE_YET

    def render_POST(self, request):
        def putfile(request):
            with hardware(request.postpath[0], 'w') as f:
                vals = csv.reader(request.args['data'][0].splitlines())
                for row in vals:
                    try:
                        real, imag = row
                    except:
                        real = row[0]
                        imag = 0
                    f.write(int(real), int(imag))
        def done(x):
            request.finish()
        def fail(x):
            request.setResponseCode(500)
            request.write('fail')
            request.finish()
        if not len(request.postpath) or request.postpath[0] not in ('emce0', 'emce1', 'emce2', 'emce3'):
            request.setResponseCode(404)
            return 'Not Found'
        threads.deferToThread(putfile, request).addCallback(done).addErrback(fail)
        return server.NOT_DONE_YET

class Stuff(static.File):
    _data_out = Data()
    def getChild(self, path, request):
        if path == 'data':
            return self._data_out
        else:
            return static.File.getChild(self, path, request)

class MatlabProtocol(LineReceiver):
    delimiter = b'\n'
    def __init__(self, factory):
        self.factory = factory
        self.status = 'IDLE'
        self.l = 0
        self.fdev = None
        self.dev = None
    def connectionLost(self, reason):
        self.factory.clients.remove(self)
        if self.dev is not None:
            self.dev.close()
        if self.fdev is not None:
            self.fdev.close()
    def connectionMade(self):
        self.factory.clients.add(self)
    def lineReceived(self, line):
        print line
        cmd = line.split(' ')
        args = cmd[1:]
        cmd = cmd[0]
        if cmd == 'set':
            hardware[args[0]] = args[1]
            self.send('OK')
        elif cmd == 'do':
            if args[0] == 'trigger/arm':
                self.status = 'avg_done'
            elif args[0] == 'transmitter/toggle':
                self.status = 'tx_toggled'
            elif args[0] == 'core/start':
                self.status = 'core_done'
            hardware[args[0]] = "1"
            self.send('OK')
        elif cmd == 'get':
            self.send(hardware[args[0]])
        elif cmd == 'read':
            l = int(args[1])
            with open('/dev/'+args[0], 'rb') as f:
                data = mmap.mmap(f.fileno(), l, mmap.MAP_SHARED, mmap.PROT_READ)
                self.transport.write(data[0:l])
                data.close()
        elif cmd == 'write':
            self.l = int(args[1])
            self.fdev = open('/dev/'+args[0], 'r+b')
            self.dev = mmap.mmap(self.fdev.fileno(), self.l, mmap.MAP_SHARED, mmap.PROT_WRITE)
            self.dev.seek(0)
            self.setRawMode()

    def rawDataReceived(self, data):
        if len(data) > self.l:
            self.dev.write(data[:self.l])
            data = data[self.l:]
            self.l = 0
        else:
            self.dev.write(data)
            self.l -= len(data)
            data = ''
        if self.l == 0:
            self.dev.close()
            self.dev = None
            self.fdev.close()
            self.fdev = None
            self.setLineMode(data)
            self.send('OK')
            
            
    def intr(self, which):
        if self.status == which:
            self.status = 'IDLE'
            self.send(which)
    def send(self, line):
        self.transport.write(line+self.delimiter)
    

class MatlabFactory(protocol.Factory):
    def __init__(self):
        self.clients = set()
    def buildProtocol(self, addr):
        return MatlabProtocol(self)

root = Stuff("web")
application = service.Application('web-ui')
site = server.Site(root)
sc = service.IServiceCollection(application)
i = internet.TCPServer(80, site)
proto = MonitorFactory()
def intr(which):
    threads.deferToThread(hardware.check).addCallback(intr)
    for target in which:
        for client in list(proto.clients):
            client.send(cmd='int', target=target)
        for client in list(matlab.clients):
            client.intr(target)
intr(())
w = internet.TCPServer(8080, WebSocketFactory(proto))
matlab = internet.TCPServer(8000, MatlabFactory())
matlab.setServiceParent(sc)
i.setServiceParent(sc)
w.setServiceParent(sc)

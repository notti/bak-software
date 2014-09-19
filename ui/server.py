#!/usr/bin/python
from twisted.application import internet, service
from twisted.web import static, server, resource
from twisted.internet import protocol, threads, reactor, defer
from txws import WebSocketFactory
import emce
import json
import csv

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

class MyFactory(protocol.Factory):
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

class PseudoClient:
    def __init__(self, which, deferred):
        self.deferred = deferred
        self.which = which
    def send(self, cmd, target):
        if cmd == 'int' and target == self.which:
            self.deferred.callback(target)

class Ctrl(resource.Resource):
    isLeaf = True
    def render_GET(self, request):
        if not len(request.postpath) or request.postpath[0] != 'capture':
            request.setResponseCode(404)
            return 'Not Found'

        def done(x):
            proto.clients.remove(pseudo)
            request.write('OK')
            request.finish()
        d = defer.Deferred()
        d.addCallback(done)
        pseudo = PseudoClient('avg_done', d)
        proto.clients.add(pseudo)
        hardware['trigger/arm'] = '1'
        return server.NOT_DONE_YET

class Stuff(static.File):
    _data_out = Data()
    _ctrl = Ctrl()
    def getChild(self, path, request):
        if path == 'data':
            return self._data_out
        elif path == 'ctrl':
            return self._ctrl
        else:
            return static.File.getChild(self, path, request)

root = Stuff("web")
application = service.Application('web-ui')
site = server.Site(root)
sc = service.IServiceCollection(application)
i = internet.TCPServer(80, site)
proto = MyFactory()
def intr(which):
    threads.deferToThread(hardware.check).addCallback(intr)
    for target in which:
        for client in list(proto.clients):
            client.send(cmd='int', target=target)
intr(())
w = internet.TCPServer(8080, WebSocketFactory(proto))
i.setServiceParent(sc)
w.setServiceParent(sc)

#!/usr/bin/python
from twisted.application import internet, service
from twisted.web import static, server
from twisted.internet import protocol
from txws import WebSocketFactory
import json

class MonitorProtocol(protocol.Protocol):
    def dataReceived(self, data):
        print data

    def send(self, **kwargs):
        self.transport.write(json.dumps(kwargs))

root = static.File("web")
application = service.Application('web-ui')
site = server.Site(root)
sc = service.IServiceCollection(application)
i = internet.TCPServer(80, site)
w = internet.TCPServer(8080, WebSocketFactory(protocol.Factory()))
i.setServiceParent(sc)
w.setServiceParent(sc)

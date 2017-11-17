import threading
import socket
import Queue
from time import time

faceThreads = []

class FaceServer(threading.Thread):
    def __init__(self, queue):
        self.stop = False
        self.queue = queue
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        faceThreads.append(self)
        threading.Thread.__init__(self)

    def recvall(self, sock):
        data = ""
        while True:
            try:
                packet = sock.recv(65536)
            except:
                return None
            data += packet
            if len(packet) > 0:
                end = packet[-1]
                if end == "a":
                    break
                elif end == "e":
                    return None
        return data

    def run(self):
        address = ("0", 0)
        self.sock.bind(address)
        self.sock.listen(5)

        print "server created {}:{}".format(self.sock.getsockname()[0], self.sock.getsockname()[1])
        hou.node("/obj/geo/streamServer/").parm("info").set("Server Created > {}:{}".format(self.sock.getsockname()[0], self.sock.getsockname()[1]))

        while self.stop != True:
            ss, addr = self.sock.accept()
            ss.send("s")
            print "get connected from", addr

            inter = 0
            fps = 0
            start_time = time()

            while True:
                data = self.recvall(ss)
                if data is None:
                    print("connection error, standby...")
                    break

                try:
                    self.queue.get_nowait()
                except Queue.Empty:
                    pass
                self.queue.put(data)

                end_time = time()
                fps += 1
                inter += end_time - start_time
                if inter >= 1:
                    print fps
                    fps = 0
                    inter -= 1
                start_time = end_time

    def close(self):
        self.sock.close()
        self.stop = True


class HouCommander(threading.Thread):
    def __init__(self, queue):
        self.stop = False
        self.queue = queue
        faceThreads.append(self)
        self.parm = hou.node("/obj/geo/streamServer/").parm("datas")
        threading.Thread.__init__(self)

    def run(self):

        inter = 0
        fps = 0
        start_time = time()

        while self.stop != True:
            self.parm.set(self.queue.get())

            end_time = time()
            fps += 1
            inter += end_time - start_time
            if inter >= 1:
                print "     -{}".format(fps)
                fps = 0
                inter -= 1
            start_time = end_time

    def close(self):
        self.stop = True


def startServer():
    faceThreads = []
    faceQueue = Queue.Queue(maxsize=1)
    f = FaceServer(faceQueue)
    h = HouCommander(faceQueue)
    f.start()
    h.start()

def closeServer():
    for s in faceThreads:
        s.close()
        print("ccccclose")
    
    print "server closed"
    hou.node("/obj/geo/streamServer/").parm("info").set("Server Closed")
    

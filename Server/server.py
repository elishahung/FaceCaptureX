import threading
import socket
import Queue
from time import time

class FaceServer(threading.Thread): # main server to receive iphone's stream
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
                if end == "a": # end receiving
                    break
                elif end == "z": # iphone stop capture
                    return None
        return data

    def run(self):
        # socket setting
        address = (hou.node("/obj/geo/streamServer/").parm("ip").eval(), 0)
        self.sock.bind(address)
        self.sock.listen(5)

        print "server created {}:{}".format(self.sock.getsockname()[0], self.sock.getsockname()[1])
        hou.node("/obj/geo/streamServer/").parm("info").set("Server Created > {}:{}".format(self.sock.getsockname()[0], self.sock.getsockname()[1]))

        while self.stop != True:
            # listen state
            ss, addr = self.sock.accept()
            ss.send("s")
            print "get connected from", addr

            # fps initial
            inter = 0
            fps = 0
            start_time = time()

            while self.stop != True:
                data = self.recvall(ss)
                if data is None: # back to listen state
                    print("connection missing, wait for connect...")
                    break

                try:
                    self.queue.get_nowait() # clean queue data
                except Queue.Empty:
                    pass
                self.queue.put(data) # put data

                # fps performance print
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


class HouCommander(threading.Thread): # when there's data, get the data and give it to houdini node's parm
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
            self.parm.set(self.queue.get()) # watch queue, if empty then wait

            # fps performance print
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
    global faceThreads
    faceThreads = []
    faceQueue = Queue.Queue(maxsize=1)
    f = FaceServer(faceQueue)
    h = HouCommander(faceQueue)
    f.start()
    h.start()

def closeServer():
    global faceThreads
    for s in faceThreads:
        s.close()
    
    print "server closed"
    hou.node("/obj/geo/streamServer/").parm("info").set("Server Closed")
    

class RoundRobinArbiter:
    def __init__(self):
        self.ptr = 0
        self.grant = 0
        self.busy = False

    def choose(self, req):
        order = [(self.ptr+i) % 3 for i in range(3)]
        for i in order:
            if (req >> i) & 1:
                return i
        return None

    def step(self, req, done=False, reset=False):
        if reset:
            self.ptr = 0
            self.grant = 0
            self.busy = False
            return self.grant, self.busy, self.ptr

        if not self.busy:
            i = self.choose(req)
            if i is not None:
                self.grant = 1 << i
                self.busy = True
        else:
            if done:
                i = {1:0, 2:1, 4:2}.get(self.grant)
                if i is not None:
                    self.ptr = (i + 1) % 3
                self.grant = 0
                self.busy = False

        return self.grant, self.busy, self.ptr


def test_all_request_rotation():
    m = RoundRobinArbiter()
    served=[]
    for _ in range(9):
        g,_,_=m.step(0b111)
        assert g in (1,2,4)
        i={1:0,2:1,4:2}[g]
        served.append(i)
        m.step(0b111, done=True)
    assert served == [0,1,2,0,1,2,0,1,2]


def test_priority_scan():
    m = RoundRobinArbiter()
    m.ptr=1
    g,_,_=m.step(0b101)
    assert g==4
    m.step(0b101, done=True)
    assert m.ptr==0


def test_single_request():
    m=RoundRobinArbiter()
    for i in range(3):
        m.ptr=i
        g,_,_=m.step(1<<((i+1)%3))
        assert g==(1<<((i+1)%3))
        m.step(0,done=True)


def test_no_request():
    m=RoundRobinArbiter()
    g,b,p=m.step(0)
    assert (g,b,p)==(0,False,0)


def test_grant_stability():
    m=RoundRobinArbiter()
    g1,b1,_=m.step(0b111)
    g2,b2,_=m.step(0b000)
    assert g1==g2 and b1 and b2
    m.step(0,done=True)


if __name__=="__main__":
    test_all_request_rotation()
    test_priority_scan()
    test_single_request()
    test_no_request()
    test_grant_stability()
    print("F07 reference model PASS")
    print("Round-robin rotation PASS")
    print("Priority scan PASS")
    print("Single-request service PASS")
    print("No-request idle PASS")
    print("Grant stability PASS")

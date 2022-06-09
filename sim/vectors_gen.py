from ast import For
import sys
import random

def hex(val, size):
    return "{0:0{1}x}".format(val, size)

def pack_gen():
    req = str(hex(random.randint(0,1),1))
    slave_addr = random.randint(0,1)*(2**31) + random.randint(0,2**31 - 1)
    addr = str(hex(slave_addr, 8))
    cmd = str(hex(random.randint(0,1),1))
    wdata = str(hex(random.randint(0,2**32 - 1), 8))
    rdata = str(hex(random.randint(0,2**32 - 1), 8))
    pack = '{0}_{1}_{2}_{3}_{4}\n'.format(req, addr, cmd, wdata, rdata)
    return pack


if __name__ == '__main__':
    P = 65                                          # N+1 of packages
    for i in range(0,4):
        path = './sim/vectors' + str(i) + '.mem'
        with open(path, 'w') as f:
            for j in range(1, P):
                f.write(pack_gen())

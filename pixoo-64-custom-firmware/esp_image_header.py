import sys, struct
for p in sys.argv[1:]:
    b = open(p,'rb').read(0x200)
    magic, nseg, mode, sizefreq, entry = struct.unpack_from('<BBBBI', b, 0)
    chip = struct.unpack_from('<H', b, 12)[0]
    # esp_app_desc_t follows image hdr (24 bytes) + first segment hdr (8 bytes)
    d = b[32:]
    dmagic = struct.unpack_from('<I', d, 0)[0]
    ver = d[16:48].split(b'\0')[0]; proj = d[48:80].split(b'\0')[0]
    t = d[80:96].split(b'\0')[0]; dt = d[96:112].split(b'\0')[0]; idf = d[112:144].split(b'\0')[0]
    print(p.split('/')[-1], hex(magic), 'segs',nseg,'chip',chip,'appdesc',hex(dmagic), ver, proj, t, dt, idf)

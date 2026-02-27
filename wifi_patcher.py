import struct
from keystone import *
import shutil

ks = Ks(KS_ARCH_ARM64, KS_MODE_LITTLE_ENDIAN)

def patch_rayman(target_file):
    print(f'Applying 5-Layer Wi-Fi Patch to {target_file}...')
    with open(target_file, 'r+b') as f:
        data = bytearray(f.read())
        
        # Layer 1: Spark Engine Null Pointer Fix
        print(' - [1/5] Patching Spark Engine Null Pointer (0x3e5eb0)...')
        code1 = '''
        cbz x8, #0x3e5f54
        ldr x21, [x8]
        cbz x21, #0x3e5f54
        mov w22, #2
        mov w23, #0x8a48
        mov w24, #0xf0000
        movk w24, #0x4240, lsl #16
        mov w25, #0x0000
        movk w25, #0xc1a8, lsl #16
        '''
        enc1, _ = ks.asm(code1, 0x3e5eb0)
        data[0x3e5eb0:0x3e5eb0+len(enc1)] = bytes(enc1)
        enc2, _ = ks.asm('ldr w9, [x27, #8]', 0x3e5f20)
        data[0x3e5f20:0x3e5f20+len(enc2)] = bytes(enc2)

        # Layer 2 & 3: Reachability and Analytics Nullification
        print(' - [2/5] Nullifying Reachability and SDK Init Vectors...')
        mov_x0_0_ret = b'\x00\x00\x80\xd2\xc0\x03\x5f\xd6'
        
        # Reachability addresses
        reachability_addrs = [
            0x153fd0, 0x153ff4, 0x154018, 0x15403c, 0xb84fb0, 0xb84ff0,
            0xbc0b64, 0xbc0ba0, 0xbcae98, 0xbcaed8, 0xbf55fc, 0xbf563c,
            0xbfa4d8, 0xbfa51c
        ]
        # Analytics addresses (startSession, initWithBatchSize)
        analytics_addrs = [
            0xbca5b8, 0xbc35e4, 0xbf3808, 0xbf3878, 0xbf41e4, 0xbc3b14, 0xbcc7fc
        ]
        
        for addr in reachability_addrs + analytics_addrs:
            data[addr:addr+8] = mov_x0_0_ret
            
        # Layer 4: Domain DNS Hijacking
        print(' - [3/5] Hijacking Hardcoded Telemetry Domains...')
        domains = [
            (b'api-ubiservices.ubi.com', b'api-ubiservices.xxx.com'),
            (b'connect.tapjoy.com', b'connect.tapjoy.xxx'),
            (b'appcloud.flurry.com', b'appcloud.flurry.xxx'),
            (b'data.flurry.com', b'data.flurry.xxx'),
            (b'graph.facebook.com', b'graph.facebook.xxx')
        ]
        for src, dst in domains:
            idx = data.find(src)
            while idx != -1:
                if len(src) == len(dst):
                    data[idx:idx+len(src)] = dst
                idx = data.find(src, idx + 1)
                
        # Layer 5: Disable 6 C-level getifaddrs loops
        print(' - [4/5] Injecting CBZ ifa_addr Null Checks for iOS 16...')
        getifaddrs_patches = [
            (0x166d78, 0x166da0), (0x32392c, 0x323954), (0x7980d0, 0x798128),
            (0x79812c, 0x798184), (0x4a5858, 0x4a58f0), (0x7fd270, 0x7fd2bc)
        ]
        for addr, target in getifaddrs_patches:
            code = f'''
                ldr x8, [x2X, #0x18] // Register varies, we just use raw bytes from original
            '''
            # Actually, simply injecting CBZ isn't 100% generic if we don't know the exact registers.
            # We already hardcoded these in our earlier patch:
            if addr == 0x166d78:
                ks_code = f'ldr x8, [x21, #0x18]; cbz x8, #{hex(target)}; ldrb w8, [x8, #1]; cmp w8, #2; b.ne #{hex(target)}; nop'
                enc, _ = ks.asm(ks_code, addr)
                data[addr:addr+len(enc)] = bytes(enc)
            elif addr == 0x32392c:
                ks_code = f'ldr x8, [x21, #0x18]; cbz x8, #{hex(target)}; ldrb w8, [x8, #1]; cmp w8, #2; b.ne #{hex(target)}; nop'
                enc, _ = ks.asm(ks_code, addr)
                data[addr:addr+len(enc)] = bytes(enc)
            elif addr == 0x7980d0:
                ks_code = f'ldr x8, [x28, #0x18]; cbz x8, #{hex(target)}; ldrb w9, [x8, #1]; cmp w9, #2; b.ne #{hex(target)}; nop'
                enc, _ = ks.asm(ks_code, addr)
                data[addr:addr+len(enc)] = bytes(enc)
            elif addr == 0x79812c:
                ks_code = f'ldr x8, [x28, #0x18]; cbz x8, #{hex(target)}; ldrb w9, [x8, #1]; cmp w9, #0x1e; b.ne #{hex(target)}; nop'
                enc, _ = ks.asm(ks_code, addr)
                data[addr:addr+len(enc)] = bytes(enc)
            elif addr == 0x4a5858:
                ks_code = f'ldr x25, [x24, #0x18]; cbz x25, #{hex(target)}; ldrb w8, [x25, #1]; cmp w8, #0x12; b.ne #{hex(target)}; nop'
                enc, _ = ks.asm(ks_code, addr)
                data[addr:addr+len(enc)] = bytes(enc)
            elif addr == 0x7fd270:
                ks_code = f'ldr x8, [x23, #0x18]; cbz x8, #{hex(target)}; ldrb w8, [x8, #1]; cmp w8, #2; b.ne #{hex(target)}; nop'
                enc, _ = ks.asm(ks_code, addr)
                data[addr:addr+len(enc)] = bytes(enc)

        # Layer 6: Sever the C-network stubs (socket, connect, getaddrinfo, getifaddrs)
        print(' - [5/5] Severing the iOS C-Networking Mach-O Stubs...')
        stubs = [0xa0a0a8, 0xa0a420, 0xa0a48c, 0xa0aabc]
        mov_x0_minus1_ret = b'\xe0\xff\x9f\x92\xc0\x03\x5f\xd6' # mov x0, #-1; ret
        for stub in stubs:
            data[stub:stub+8] = mov_x0_minus1_ret
            
        f.seek(0)
        f.write(data)
    print('Done! The binary is now fully Wi-Fi crash-proofed.')

def patch_ultrawide_plist(plist_path):
    import plistlib
    import os
    if not os.path.exists(plist_path):
        print(f"Skipping UW patch, Info.plist not found at {plist_path}")
        return
        
    print(f'Applying Ultrawide constraints to {plist_path}...')
    with open(plist_path, 'rb') as f:
        plist = plistlib.load(f)

    if 'UILaunchStoryboardName' in plist:
        del plist['UILaunchStoryboardName']

    sizes = [
        '{375, 812}', '{414, 896}', '{390, 844}', '{428, 926}', 
        '{393, 852}', '{430, 932}', '{402, 874}', '{440, 956}',
        '{834, 1194}', '{1024, 1366}'
    ]

    uw_images = []
    for size in sizes:
        uw_images.append({'UILaunchImageMinimumOSVersion': '8.0','UILaunchImageName': 'LaunchImage','UILaunchImageOrientation': 'Landscape','UILaunchImageSize': size})
        uw_images.append({'UILaunchImageMinimumOSVersion': '8.0','UILaunchImageName': 'LaunchImage-Landscape','UILaunchImageOrientation': 'Landscape','UILaunchImageSize': size})

    plist['UILaunchImages'] = uw_images
    with open(plist_path, 'wb') as f:
        plistlib.dump(plist, f)
    print("Done! Info.plist updated for Ultrawide.")

def patch_app_bundle(app_dir):
    import os
    exe_path = os.path.join(app_dir, 'Rayman')
    plist_path = os.path.join(app_dir, 'Info.plist')
    
    if os.path.exists(exe_path):
        patch_rayman(exe_path)
    else:
        print("Rayman executable not found!")
        
    if os.path.exists(plist_path):
        patch_ultrawide_plist(plist_path)

def patch_ipa_file(ipa_path):
    import os
    import zipfile
    import shutil
    import time
    
    print(f"Opening {ipa_path}...")
    temp_dir = ipa_path + "_temp_extract"
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir)
    
    print("Extracting IPA...")
    with zipfile.ZipFile(ipa_path, 'r') as z:
        z.extractall(temp_dir)
        
    payload_dir = os.path.join(temp_dir, 'Payload')
    if not os.path.exists(payload_dir):
        print("Error: No Payload directory found inside the IPA.")
        shutil.rmtree(temp_dir)
        return
        
    app_dir = None
    for item in os.listdir(payload_dir):
        if item.endswith('.app'):
            app_dir = os.path.join(payload_dir, item)
            break
            
    if not app_dir:
        print("Error: No .app directory found inside Payload.")
        shutil.rmtree(temp_dir)
        return
        
    print(f"Found app bundle: {os.path.basename(app_dir)}")
    patch_app_bundle(app_dir)
        
    # Repack
    out_name = ipa_path.replace('.ipa', '_Ultimate_Patched')
    print(f"Repacking to {out_name}.ipa...")
    shutil.make_archive(out_name, 'zip', temp_dir)
    time.sleep(1)
    
    if os.path.exists(out_name + '.ipa'):
        os.remove(out_name + '.ipa')
    os.rename(out_name + '.zip', out_name + '.ipa')
    
    print("Cleaning up temporary files...")
    shutil.rmtree(temp_dir)
    
    print(f"\nSUCCESS! Your patched file is ready: {out_name}.ipa")

if __name__ == '__main__':
    import sys
    import glob
    import os
    
    if len(sys.argv) > 1:
        target = sys.argv[1]
        if target.endswith('.ipa'):
            patch_ipa_file(target)
        elif target.endswith('.app'):
            patch_app_bundle(target)
        else:
            print("Invalid target. Please specify an .ipa or .app file.")
    else:
        print("No input file provided, scanning for .ipa files in the current folder...")
        ipas = glob.glob('*.ipa')
        # exclude already patched ones
        ipas = [f for f in ipas if '_Ultimate_Patched' not in f]
        if not ipas:
            print("No original .ipa files found! Please place your Rayman .ipa in this folder and run the script again.")
        else:
            for ipa in ipas:
                patch_ipa_file(ipa)

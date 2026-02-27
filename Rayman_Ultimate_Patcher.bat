1>2# : ^
'''
@echo off
setlocal
echo =======================================================
echo Rayman Anniversary: Ultimate Widescreen + Wi-Fi Patcher
echo =======================================================
if "%~1"=="" (
    echo.
    echo ERROR: No file provided!
    echo Please DRAG AND DROP your Rayman .ipa file directly 
    echo onto this Rayman_Ultimate_Patcher.bat file.
    echo.
    pause
    exit /b
)
echo Starting Automated Patcher...
python -x "%~f0" "%~1"
echo.
pause
exit /b
'''



# ----------------- PYTHON CODE STARTS HERE -----------------
import sys
import os
import zipfile
import shutil
import plistlib
import time

def patch_rayman(target_file):
    print(f'Applying 5-Layer Wi-Fi Patch to {target_file}...')
    with open(target_file, 'r+b') as f:
        data = bytearray(f.read())
        
        print(' - [1/5] Patching Spark Engine Null Pointer...')
        enc1 = b'\x28\x05\x00\xb4\x15\x01\x40\xf9\xf5\x04\x00\xb4\x56\x00\x80\x52\x17\x49\x91\x52\xf8\x01\xa0\x52\x18\x48\xa8\x72\x19\x00\x80\x52\x19\x35\xb8\x72'
        data[0x3e5eb0:0x3e5eb0+len(enc1)] = enc1
        enc2 = b'\x69\x0b\x40\xb9'
        data[0x3e5f20:0x3e5f20+len(enc2)] = enc2

        print(' - [2/5] Nullifying Reachability and SDK Init Vectors...')
        mov_x0_0_ret = b'\x00\x00\x80\xd2\xc0\x03\x5f\xd6'
        reachability_addrs = [0x153fd0, 0x153ff4, 0x154018, 0x15403c, 0xb84fb0, 0xb84ff0, 0xbc0b64, 0xbc0ba0, 0xbcae98, 0xbcaed8, 0xbf55fc, 0xbf563c, 0xbfa4d8, 0xbfa51c]
        analytics_addrs = [0xbca5b8, 0xbc35e4, 0xbf3808, 0xbf3878, 0xbf41e4, 0xbc3b14, 0xbcc7fc]
        for addr in reachability_addrs + analytics_addrs:
            data[addr:addr+8] = mov_x0_0_ret
            
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
                
        print(' - [4/5] Injecting CBZ ifa_addr Null Checks for iOS 16...')
        data[0x166d78:0x166d78+24] = b'\xa8\x0e\x40\xf9\x28\x01\x00\xb4\x08\x05\x40\x39\x1f\x09\x00\x71\xc1\x00\x00\x54\x1f\x20\x03\xd5'
        data[0x32392c:0x32392c+24] = b'\xa8\x0e\x40\xf9\x28\x01\x00\xb4\x08\x05\x40\x39\x1f\x09\x00\x71\xc1\x00\x00\x54\x1f\x20\x03\xd5'
        data[0x7980d0:0x7980d0+24] = b'\x88\x0f\x40\xf9\xa8\x02\x00\xb4\x09\x05\x40\x39\x3f\x09\x00\x71\x41\x02\x00\x54\x1f\x20\x03\xd5'
        data[0x79812c:0x79812c+24] = b'\x88\x0f\x40\xf9\xa8\x02\x00\xb4\x09\x05\x40\x39\x3f\x79\x00\x71\x41\x02\x00\x54\x1f\x20\x03\xd5'
        data[0x4a5858:0x4a5858+24] = b'\x19\x0f\x40\xf9\xb9\x04\x00\xb4\x28\x07\x40\x39\x1f\x49\x00\x71\x41\x04\x00\x54\x1f\x20\x03\xd5'
        data[0x7fd270:0x7fd270+24] = b'\xe8\x0e\x40\xf9\x48\x02\x00\xb4\x08\x05\x40\x39\x1f\x09\x00\x71\xe1\x01\x00\x54\x1f\x20\x03\xd5'

        print(' - [5/5] Severing the iOS C-Networking Mach-O Stubs...')
        stubs = [0xa0a0a8, 0xa0a420, 0xa0a48c, 0xa0aabc]
        mov_x0_minus1_ret = b'\xe0\xff\x9f\x92\xc0\x03\x5f\xd6'
        for stub in stubs:
            data[stub:stub+8] = mov_x0_minus1_ret
            
        f.seek(0)
        f.write(data)
    print('Done! The binary is now absolutely Wi-Fi crash-proofed.')

def patch_ultrawide_plist(plist_path):
    if not os.path.exists(plist_path):
        return
        
    print(f'Applying Native Ultrawide constraints to Info.plist...')
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

def patch_ipa_file(ipa_path):
    print(f"\nOpening {os.path.basename(ipa_path)}...")
    temp_dir = ipa_path + "_temp_extract"
    if os.path.exists(temp_dir):
        shutil.rmtree(temp_dir)
    os.makedirs(temp_dir)
    
    print("Extracting IPA... (this might take a few seconds)")
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
        
    exe_path = os.path.join(app_dir, 'Rayman')
    plist_path = os.path.join(app_dir, 'Info.plist')
    
    if os.path.exists(exe_path):
        patch_rayman(exe_path)
    if os.path.exists(plist_path):
        patch_ultrawide_plist(plist_path)
        
    out_name = ipa_path.replace('.ipa', '_Ultimate_Patched')
    print(f"Repacking to {os.path.basename(out_name)}.ipa...")
    shutil.make_archive(out_name, 'zip', temp_dir)
    time.sleep(1)
    
    if os.path.exists(out_name + '.ipa'):
        os.remove(out_name + '.ipa')
    os.rename(out_name + '.zip', out_name + '.ipa')
    
    print("Cleaning up temporary files...")
    shutil.rmtree(temp_dir)
    
    print(f"\nSUCCESS! Your patched file is ready: {os.path.basename(out_name)}.ipa")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        target = sys.argv[1]
        if target.endswith('.ipa'):
            patch_ipa_file(target)
        else:
            print("Invalid target. Please drop an .ipa file onto the batch launcher.")

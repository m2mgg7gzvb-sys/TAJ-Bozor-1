p = 'android/app/src/main/AndroidManifest.xml'
s = open(p, encoding='utf-8').read()
names = ['INTERNET', 'RECORD_AUDIO', 'MODIFY_AUDIO_SETTINGS',
         'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION']
perms = ''.join('    <uses-permission android:name="android.permission.%s"/>\n' % n for n in names)
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', perms + '    <application', 1)
open(p, 'w', encoding='utf-8').write(s)
print('permissions ok')

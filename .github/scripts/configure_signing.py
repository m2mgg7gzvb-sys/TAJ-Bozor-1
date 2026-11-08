import os, re

KTS = 'android/app/build.gradle.kts'
GROOVY = 'android/app/build.gradle'

KTS_BLOCK = (
    '    signingConfigs {\n'
    '        create("release") {\n'
    '            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH"))\n'
    '            storePassword = System.getenv("ANDROID_STORE_PASSWORD")\n'
    '            keyAlias = System.getenv("ANDROID_KEY_ALIAS")\n'
    '            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")\n'
    '        }\n'
    '    }\n'
)
GROOVY_BLOCK = (
    '    signingConfigs {\n'
    '        release {\n'
    '            storeFile file(System.getenv("ANDROID_KEYSTORE_PATH"))\n'
    '            storePassword System.getenv("ANDROID_STORE_PASSWORD")\n'
    '            keyAlias System.getenv("ANDROID_KEY_ALIAS")\n'
    '            keyPassword System.getenv("ANDROID_KEY_PASSWORD")\n'
    '        }\n'
    '    }\n'
)

if os.path.exists(KTS):
    p, block = KTS, KTS_BLOCK
else:
    p, block = GROOVY, GROOVY_BLOCK

s = open(p, encoding='utf-8').read()
s = s.replace('    buildTypes {', block + '    buildTypes {', 1)
s = re.sub(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
           'signingConfig = signingConfigs.getByName("release")', s)
s = s.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.release')
open(p, 'w', encoding='utf-8').write(s)
print('signing ok:', p)

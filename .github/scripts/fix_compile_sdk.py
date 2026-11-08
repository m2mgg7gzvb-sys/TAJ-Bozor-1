# Все Android-модули (включая плагины) собираются против SDK 36.
p = 'android/build.gradle.kts'
block = '''
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(36)
    }
}
'''
s = open(p, encoding='utf-8').read()
if 'compileSdkVersion(36)' not in s:
    open(p, 'w', encoding='utf-8').write(s + block)
print('compileSdk 36 ok')

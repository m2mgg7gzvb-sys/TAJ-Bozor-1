# Все Android-библиотеки (плагины) собираются против SDK 36.
# withPlugin работает и тогда, когда модуль уже вычислен (Flutter так делает).
p = 'android/build.gradle.kts'
block = '''
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 36
        }
    }
}
'''
s = open(p, encoding='utf-8').read()
if 'withPlugin("com.android.library")' not in s:
    open(p, 'w', encoding='utf-8').write(s + block)
print('compileSdk 36 ok')

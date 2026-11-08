# Все Android-библиотеки (плагины) собираются против SDK 36.
# Плагин сам задаёт compileSdk в своём build.gradle, поэтому ставим значение после его вычисления.
p = 'android/build.gradle.kts'
block = '''
subprojects {
    fun setSdk() {
        (extensions.findByName("android") as? com.android.build.gradle.BaseExtension)?.compileSdkVersion(36)
    }
    if (state.executed) setSdk() else afterEvaluate { setSdk() }
}
'''
s = open(p, encoding='utf-8').read()
if 'fun setSdk()' not in s:
    open(p, 'w', encoding='utf-8').write(s + block)
print('compileSdk 36 ok')

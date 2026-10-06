# O build release liga o R8 por padrão (via flutter-gradle-plugin). O R8 já tem uma regra
# genérica para não remover classes que implementam FlutterPlugin, mas ainda permite encurtar
# (allowshrinking) e renomear (allowobfuscation) os métodos — o que já foi reportado quebrando
# o retorno de callbacks nativos → Dart em alguns plugins só no build release (nunca no debug,
# que não passa pelo R8). Veja https://github.com/flutter/flutter/issues/154580.
#
# O nfc_manager depende desse caminho nativo → Dart (enableReaderMode entrega a tag num
# callback do SO, não por uma chamada vinda do Dart), então mantemos a classe do plugin e o
# código gerado pelo Pigeon inteiros, sem encurtar nem renomear.
-keep class dev.flutter.plugins.nfcmanager.** { *; }
-keepclassmembers class dev.flutter.plugins.nfcmanager.** { *; }

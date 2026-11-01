import 'package:flutter/foundation.dart';

/// Текущая вкладка нижнего меню. Позволяет открыть «Войти» из любого экрана.
final tabIndex = ValueNotifier<int>(0);

/// Индекс вкладки «Войти».
const int loginTabIndex = 4;

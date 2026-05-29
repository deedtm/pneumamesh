import 'package:logger/logger.dart';

// создаем один инстанс на все приложение
final log = Logger(
  printer: PrettyPrinter(
    methodCount: 1,       // сколько строк из стека вызовов показывать (1 — за глаза)
    errorMethodCount: 5,  // сколько строк стека показывать, если прилетела ошибка
    lineLength: 80,       // длина разделительных линий
    colors: true,         // врубить цвета в консоли
    printEmojis: true,    // эмодзи для каждого типа лога
  ),
);
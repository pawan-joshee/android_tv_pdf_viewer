import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState get navigator => navigatorKey.currentState!;

  static Future<T?> pushNamed<T>(String route, {Object? arguments}) {
    return navigator.pushNamed(route, arguments: arguments);
  }

  static Future<T?> push<T>(Route<T> route) {
    return navigator.push(route);
  }

  static void pop<T>([T? result]) {
    return navigator.pop(result);
  }

  static bool canPop() {
    return navigator.canPop();
  }
}

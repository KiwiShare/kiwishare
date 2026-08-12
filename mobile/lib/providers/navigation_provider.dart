import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _activeTab = 0;
  int get activeTab => _activeTab;

  void setActiveTab(int tabIndex) {
    if (_activeTab != tabIndex) {
      _activeTab = tabIndex;
      notifyListeners();
    }
  }
}

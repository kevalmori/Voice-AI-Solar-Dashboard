import '../services/webview_controller_service.dart';

class NavigationTools {
  final WebViewControllerService webView;

  NavigationTools(this.webView);

  Future<String> openDashboard() async {
    return await webView.navigateTo('/dashboard');
  }

  Future<String> openPlants() async {
    return await webView.navigateTo('/plants');
  }

  Future<String> openInverters() async {
    return await webView.navigateTo('/inverters');
  }

  Future<String> openSlms() async {
    return await webView.navigateTo('/slmsDevices');
  }

  Future<String> openSensors() async {
    return await webView.navigateTo('/sensors');
  }
}

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/webview_controller_service.dart';
import '../config.dart';

class WebViewContainer extends StatefulWidget {
  final WebViewControllerService webViewService;

  const WebViewContainer({super.key, required this.webViewService});

  @override
  State<WebViewContainer> createState() => _WebViewContainerState();
}

class _WebViewContainerState extends State<WebViewContainer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _progress = 0;
            });
            widget.webViewService.updateCurrentUrl(url);
          },
          onProgress: (progress) {
            setState(() => _progress = progress / 100.0);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            widget.webViewService.updateCurrentUrl(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(AppConfig.dashboardUrl));

    widget.webViewService.setController(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6C63FF),
              ),
              minHeight: 3,
            ),
          ),
      ],
    );
  }
}

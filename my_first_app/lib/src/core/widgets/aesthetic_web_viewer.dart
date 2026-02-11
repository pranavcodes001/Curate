import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AestheticWebViewer extends StatefulWidget {
  final String url;

  const AestheticWebViewer({super.key, required this.url});

  static Future<void> show(BuildContext context, String url) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => AestheticWebViewer(url: url),
    );
  }

  @override
  State<AestheticWebViewer> createState() => _AestheticWebViewerState();
}

class _AestheticWebViewerState extends State<AestheticWebViewer> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _progress = 0;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            // Handle and Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // Neon Glowing Progress Bar
            if (_isLoading)
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00E5FF),
                  ),
                ),
              ),

            // WebView
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(
                    controller: _controller,
                    gestureRecognizers: {
                      Factory<VerticalDragGestureRecognizer>(
                        () => VerticalDragGestureRecognizer(),
                      ),
                      Factory<HorizontalDragGestureRecognizer>(
                        () => HorizontalDragGestureRecognizer(),
                      ),
                      Factory<ScaleGestureRecognizer>(
                        () => ScaleGestureRecognizer(),
                      ),
                      Factory<TapGestureRecognizer>(
                        () => TapGestureRecognizer(),
                      ),
                    },
                  ),
                  if (_isLoading && _progress < 0.1)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Minimalist Bottom Nav
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                top: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () async {
                      if (await _controller.canGoBack()) {
                        await _controller.goBack();
                      }
                    },
                  ),
                  _navButton(
                    icon: Icons.refresh,
                    onTap: () => _controller.reload(),
                  ),
                  _navButton(
                    icon: Icons.link_rounded,
                    onTap: () async {
                      final url = await _controller.currentUrl();
                      if (url != null) {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  _navButton(
                    icon: Icons.arrow_forward_ios,
                    onTap: () async {
                      if (await _controller.canGoForward()) {
                        await _controller.goForward();
                      }
                    },
                  ),
                  _navButton(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:google_identity_services_web/id.dart' as gis_id;
import 'package:web/web.dart' as web;

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  static bool _registered = false;
  static const String _viewType = 'google-signin-btn';

  @override
  void initState() {
    super.initState();
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) {
          final div = web.document.createElement('div') as web.HTMLDivElement;
          div.id = 'google-btn-$viewId';
          div.style.width = '100%';
          div.style.height = '100%';
          div.style.display = 'flex';
          div.style.justifyContent = 'center';
          div.style.alignItems = 'center';

          Future.microtask(() {
            try {
              gis_id.id.renderButton(
                div,
                gis_id.GsiButtonConfiguration(
                  type: gis_id.ButtonType.standard,
                  theme: gis_id.ButtonTheme.filled_blue,
                  size: gis_id.ButtonSize.large,
                  text: gis_id.ButtonText.signin_with,
                  shape: gis_id.ButtonShape.pill,
                  logo_alignment: gis_id.ButtonLogoAlignment.left,
                  width: 320.0,
                ),
              );
            } catch (e) {
              Future.delayed(const Duration(milliseconds: 200), () {
                try {
                  gis_id.id.renderButton(
                    div,
                    gis_id.GsiButtonConfiguration(
                      type: gis_id.ButtonType.standard,
                      theme: gis_id.ButtonTheme.filled_blue,
                      size: gis_id.ButtonSize.large,
                      text: gis_id.ButtonText.signin_with,
                      shape: gis_id.ButtonShape.pill,
                      logo_alignment: gis_id.ButtonLogoAlignment.left,
                      width: 320.0,
                    ),
                  );
                } catch (_) {}
              });
            }
          });
          return div;
        },
      );
      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 320,
      height: 50,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

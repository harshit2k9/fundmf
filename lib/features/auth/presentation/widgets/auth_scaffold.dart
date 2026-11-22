import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/risk_disclaimer.dart';

/// Responsive auth layout: on wide screens a navy brand panel sits beside the
/// form; on phones the form fills the screen with a compact brand header.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final form = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (!isWide) ...<Widget>[
                          const _CompactBrand(),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 28),
                        child,
                        if (footer != null) ...<Widget>[
                          const SizedBox(height: 20),
                          footer!,
                        ],
                        const SizedBox(height: 28),
                        const RiskDisclaimer(),
                      ],
                    ),
                  ),
                ),
              ),
            );

            if (!isWide) return form;

            return Row(
              children: <Widget>[
                const Expanded(flex: 5, child: _BrandPanel()),
                Expanded(flex: 6, child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Image.asset(
          'assets/logo.png',
          width: 36,
          height: 36,
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppConstants.appName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'Powered by Compounding',
              style: TextStyle(fontSize: 11.5, color: AppColors.slate),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.navyDeep, AppColors.navy, AppColors.navySoft],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              Image.asset(
                'assets/logo.png',
                width: 36,
                height: 36,
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppConstants.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Powered by Compounding',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 44),
          const Text(
            'Your mutual fund\nportfolio, reconciled.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Fundmf reads your CAMS statements, tracks every folio and values '
            'your holdings against the latest AMFI NAV.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          const _Feature(
            icon: Icons.verified_user_outlined,
            text: 'Admin-verified access — no public sign-ups',
          ),
          const SizedBox(height: 18),
          const _Feature(
            icon: Icons.mark_email_read_outlined,
            text: 'CAMS statements parsed automatically every day at 9 AM',
          ),
          const SizedBox(height: 18),
          const _Feature(
            icon: Icons.show_chart_rounded,
            text: 'Live NAV, absolute P&L and scheme-wise returns',
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: AppColors.emerald, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

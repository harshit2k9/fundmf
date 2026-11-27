import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/risk_disclaimer.dart';

/// Responsive auth layout: on wide screens an ink brand panel sits beside the
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
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final form = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (!isWide) ...<Widget>[
                          const _CompactBrand(),
                          const SizedBox(height: 30),
                        ] else
                          const _FormEyebrow(),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.9,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.slate,
                            fontSize: 13,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 26),
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
                Expanded(
                  flex: 6,
                  child: Container(
                    color: AppColors.canvas,
                    child: form,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: compact ? 15 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: compact ? AppColors.ink : Colors.white,
          ),
        ),
        const SizedBox(height: 1),
        const Text(
          'POWERED BY COMPOUNDING',
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.goldSoft,
          ),
        ),
      ],
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const _BrandMark(),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 1),
            Text(
              'POWERED BY COMPOUNDING',
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.goldDeep,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormEyebrow extends StatelessWidget {
  const _FormEyebrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: <Widget>[
          Container(width: 22, height: 2, color: AppColors.gold),
          const SizedBox(width: 8),
          const Text(
            'SECURE INVESTOR ACCESS',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.slate,
            ),
          ),
        ],
      ),
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
          colors: <Color>[AppColors.inkDeep, AppColors.ink, AppColors.inkSoft],
        ),
      ),
      padding: const EdgeInsets.all(52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _BrandMark(size: 36),
              const SizedBox(width: 12),
              const _Wordmark(compact: false),
            ],
          ),
          const SizedBox(height: 40),
          Container(width: 44, height: 2, color: AppColors.gold),
          const SizedBox(height: 22),
          const Text(
            'Wealth,\nclearly measured.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Fundmf consolidates every folio from your CAMS and KFintech '
            'statements and values it against the latest AMFI NAV — one '
            'statement, one number, no spreadsheets.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 13.5,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 38),
          const _Feature(
            icon: Icons.shield_outlined,
            text: 'Invite-only access, verified by the Fundmf admin',
          ),
          const SizedBox(height: 16),
          const _Feature(
            icon: Icons.mark_email_read_outlined,
            text: 'Statements parsed automatically every morning',
          ),
          const SizedBox(height: 16),
          const _Feature(
            icon: Icons.picture_as_pdf_outlined,
            text: 'Portfolio statements and ledgers as PDF or CSV',
          ),
          const SizedBox(height: 40),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.09),
          ),
          const SizedBox(height: 14),
          Text(
            'Prepared for ${AppConstants.supportEmail}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
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
        Icon(icon, color: AppColors.goldSoft, size: 17),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

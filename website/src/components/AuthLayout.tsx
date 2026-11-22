import type { ReactNode } from 'react';

import { Brand } from './Brand';
import { DownloadApkButton } from './DownloadApk';
import { RiskDisclaimer } from './RiskDisclaimer';

/** Two-column brand panel on desktop, single column on phones. */
export function AuthLayout({ children }: { children: ReactNode }) {
  return (
    <div className="auth">
      <aside className="auth-brand">
        <Brand onDark size={40} />
        <h1>
          Every folio,
          <br />
          one clear picture.
        </h1>
        <p>
          Fundmf consolidates your CAMS and KFintech statements into a single
          portfolio view — live NAVs, scheme-wise gains, and every transaction
          in one place.
        </p>
        <div className="auth-highlights">
          <div className="auth-highlight">
            <span className="dot">✓</span>
            <span>Statement sync from CAMS &amp; KFintech, no manual uploads</span>
          </div>
          <div className="auth-highlight">
            <span className="dot">✓</span>
            <span>Average-cost P&amp;L with live AMFI NAVs</span>
          </div>
          <div className="auth-highlight">
            <span className="dot">✓</span>
            <span>Admin-provisioned access — your data stays yours</span>
          </div>
        </div>
      </aside>

      <main className="auth-panel">
        <div className="auth-mobile-brand">
          <Brand />
        </div>
        <div className="auth-card">{children}</div>
        <div className="auth-footer">
          <div className="auth-apk">
            <DownloadApkButton
              className="btn btn-accent btn-block"
              label="Download the Android app"
            />
          </div>
          <RiskDisclaimer onCanvas={false} />
        </div>
      </main>
    </div>
  );
}

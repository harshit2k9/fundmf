import type { ReactNode } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';

import { useIsMobile } from '../hooks/useMediaQuery';
import { useAuth } from '../lib/auth';
import { Brand } from './Brand';
import { RiskDisclaimer } from './RiskDisclaimer';
import { DownloadApkButton } from './DownloadApk';

export interface NavItem {
  to: string;
  label: string;
  icon: string;
}

/**
 * Desktop: fixed sidebar + content column.
 * Phone: compact top bar, bottom navigation and the APK download entry point —
 * the app-style UI the mobile requirements ask for.
 */
export function Shell({
  items,
  title,
  subtitle,
  actions,
  children,
}: {
  items: NavItem[];
  title: string;
  subtitle?: string;
  actions?: ReactNode;
  children: ReactNode;
}) {
  const isMobile = useIsMobile();
  const { profile, user, signOut } = useAuth();
  const navigate = useNavigate();

  const identity = profile?.fullName || user?.email || '';

  if (isMobile) {
    return (
      <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
        <header className="mobile-topbar">
          <Brand size={28} />
          <div className="row" style={{ gap: 8 }}>
            <DownloadApkButton className="btn btn-ghost btn-sm" label="APK" />
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              onClick={() => void signOut()}
            >
              Sign out
            </button>
          </div>
        </header>

        <main className="mobile-body">
          <div className="row-between" style={{ marginBottom: 14 }}>
            <div>
              <div className="page-title">{title}</div>
              {subtitle ? <div className="small muted">{subtitle}</div> : null}
            </div>
            {actions}
          </div>
          {children}
          <RiskDisclaimer />
        </main>

        <nav className="bottomnav">
          {items.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                `bottomnav-item${isActive ? ' active' : ''}`
              }
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>
      </div>
    );
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <Brand onDark />
        <nav className="nav">
          {items.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}
            >
              <span className="nav-icon">{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-foot">
          <DownloadApkButton className="btn btn-ghost btn-sm" label="Download APK" />
          <div className="sidebar-user">
            {identity ? <div>{identity}</div> : null}
            <div>{profile?.clientId || (user?.email ?? '')}</div>
            <button
              type="button"
              className="nav-item"
              style={{ marginTop: 8, paddingLeft: 0 }}
              onClick={() => {
                void signOut().then(() => navigate('/login'));
              }}
            >
              <span className="nav-icon">↩</span> Sign out
            </button>
          </div>
        </div>
      </aside>

      <div className="main">
        <header className="topbar">
          <div>
            <div className="page-title">{title}</div>
            {subtitle ? <div className="small muted">{subtitle}</div> : null}
          </div>
          <div className="row">{actions}</div>
        </header>
        <div className="main-body">{children}</div>
        <RiskDisclaimer />
      </div>
    </div>
  );
}

export const investorNav: NavItem[] = [
  { to: '/dashboard', label: 'Dashboard', icon: '◔' },
  { to: '/transactions', label: 'Transactions', icon: '☰' },
  { to: '/profile', label: 'Profile', icon: '☺' },
];

export const adminNav: NavItem[] = [
  { to: '/admin/clients', label: 'Clients', icon: '⚇' },
  { to: '/admin/sync', label: 'CAMS sync', icon: '⟳' },
];

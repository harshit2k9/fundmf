import type { ReactNode } from 'react';

export function StatusBadge({ status }: { status: string }) {
  const value = (status ?? '').toLowerCase();
  const variant =
    value === 'success'
      ? 'success'
      : value === 'partial'
        ? 'partial'
        : value === 'failed' || value === 'error'
          ? 'failed'
          : 'neutral';
  return <span className={`badge ${variant}`}>{value || 'unknown'}</span>;
}

export function AccountBadge({
  approved,
  linked,
}: {
  approved: boolean;
  linked: boolean;
}) {
  const label = !linked ? 'unclaimed' : approved ? 'active' : 'pending';
  const variant = !linked ? 'neutral' : approved ? 'success' : 'partial';
  return <span className={`badge ${variant}`}>{label}</span>;
}

export function Loading({ label = 'Loading…' }: { label?: string }) {
  return (
    <div className="loading-block">
      <span className="spinner" />
      <span>{label}</span>
    </div>
  );
}

export function EmptyState({
  title,
  children,
}: {
  title: string;
  children?: ReactNode;
}) {
  return (
    <div className="empty">
      <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--navy)', marginBottom: 6 }}>
        {title}
      </div>
      {children}
    </div>
  );
}

export function Field({
  label,
  children,
  error,
}: {
  label: string;
  children: ReactNode;
  error?: string | null;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      {children}
      {error ? <span className="input-error">{error}</span> : null}
    </div>
  );
}

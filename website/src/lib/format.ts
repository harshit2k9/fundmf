/** Indian-digit-grouping money and date helpers, matching the Flutter app. */

const currency = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const plain = new Intl.NumberFormat('en-IN', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const unitFormat = new Intl.NumberFormat('en-IN', {
  minimumFractionDigits: 3,
  maximumFractionDigits: 3,
});

export const fmtCurrency = (value: number | null | undefined): string =>
  currency.format(value ?? 0);

/** `+₹1,234.00` / `-₹1,234.00` */
export const fmtSignedCurrency = (value: number | null | undefined): string => {
  const v = value ?? 0;
  const sign = v > 0 ? '+' : v < 0 ? '-' : '';
  return `${sign}${currency.format(Math.abs(v))}`;
};

export const fmtAmount = (value: number | null | undefined): string =>
  plain.format(value ?? 0);

/** `+12.34%` */
export const fmtSignedPercent = (value: number | null | undefined): string => {
  const v = value ?? 0;
  const sign = v > 0 ? '+' : v < 0 ? '-' : '';
  return `${sign}${Math.abs(v).toFixed(2)}%`;
};

export const fmtPercent = (value: number | null | undefined): string =>
  `${(value ?? 0).toFixed(2)}%`;

export const fmtUnits = (value: number | null | undefined): string =>
  unitFormat.format(value ?? 0);

export const fmtNav = (value: number | null | undefined): string =>
  (value ?? 0).toFixed(4);

const dateFmt = new Intl.DateTimeFormat('en-IN', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
});

const dateTimeFmt = new Intl.DateTimeFormat('en-IN', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
  hour12: true,
});

export const fmtDate = (value: Date | null | undefined): string =>
  value ? dateFmt.format(value) : '—';

export const fmtDateTime = (value: Date | null | undefined): string =>
  value ? dateTimeFmt.format(value) : '—';

export const fmtDuration = (ms: number): string => {
  if (ms < 1000) return `${Math.round(ms)}ms`;
  const seconds = ms / 1000;
  if (seconds < 60) return `${seconds.toFixed(1)}s`;
  const minutes = Math.floor(seconds / 60);
  return `${minutes}m ${Math.round(seconds % 60)}s`;
};

/** `ABCDE1234F` -> `ABCDE••••F` */
export const maskPan = (pan: string): string => {
  const value = (pan ?? '').trim();
  if (value.length < 6) return value;
  return `${value.slice(0, 5)}••••${value.slice(-1)}`;
};

export const initials = (name: string): string => {
  const parts = (name ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'F';
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
};

export const firstName = (name: string): string => {
  const trimmed = (name ?? '').trim();
  return trimmed ? trimmed.split(/\s+/)[0] : 'there';
};

export const greeting = (now: Date = new Date()): string => {
  const hour = now.getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
};

export const changeClass = (value: number): string =>
  value > 0 ? 'gain' : value < 0 ? 'loss' : 'flat';

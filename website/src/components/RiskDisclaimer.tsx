export const RISK_DISCLAIMER_TEXT =
  'Mutual Funds are subject to market risk. Invest wisely';

/** Persistent footer used on every shell and auth screen. */
export function RiskDisclaimer({ onCanvas = true }: { onCanvas?: boolean }) {
  return (
    <div className={`disclaimer${onCanvas ? ' on-canvas' : ''}`}>
      {RISK_DISCLAIMER_TEXT}
    </div>
  );
}

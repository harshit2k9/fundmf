import { fmtCurrency } from '../lib/format';
import type { SchemeHolding } from '../lib/types';

const PALETTE = [
  '#1B3A63',
  '#10B981',
  '#3B82F6',
  '#F59E0B',
  '#8B5CF6',
  '#EC4899',
  '#14B8A6',
  '#F97316',
];

const shortName = (name: string): string =>
  name.length <= 30 ? name : `${name.slice(0, 27)}…`;

/** Scheme allocation donut + legend, mirroring the app's allocation chart. */
export function AllocationDonut({
  holdings,
  size = 168,
}: {
  holdings: SchemeHolding[];
  size?: number;
}) {
  const total = holdings.reduce((sum, holding) => sum + holding.currentValue, 0);
  const radius = size / 2 - 12;
  const circumference = 2 * Math.PI * radius;
  const center = size / 2;

  let offset = 0;

  return (
    <div className="donut-wrap">
      <svg
        className="donut"
        width={size}
        height={size}
        viewBox={`0 0 ${size} ${size}`}
        role="img"
        aria-label="Portfolio allocation by scheme"
      >
        <circle
          cx={center}
          cy={center}
          r={radius}
          fill="none"
          stroke="#EEF2F7"
          strokeWidth={16}
        />
        {total > 0 &&
          holdings.map((holding, index) => {
            const fraction = holding.currentValue / total;
            const dash = fraction * circumference;
            const circle = (
              <circle
                key={`${holding.schemeCode}-${holding.schemeName}`}
                cx={center}
                cy={center}
                r={radius}
                fill="none"
                stroke={PALETTE[index % PALETTE.length]}
                strokeWidth={16}
                strokeDasharray={`${dash} ${circumference - dash}`}
                strokeDashoffset={-offset}
                strokeLinecap="butt"
                transform={`rotate(-90 ${center} ${center})`}
              />
            );
            offset += dash;
            return circle;
          })}
        <text
          x={center}
          y={center - 4}
          textAnchor="middle"
          fontSize="10"
          fill="#64748B"
        >
          CURRENT VALUE
        </text>
        <text
          x={center}
          y={center + 15}
          textAnchor="middle"
          fontSize="14"
          fontWeight="700"
          fill="#0B2447"
        >
          {fmtCurrency(total)}
        </text>
      </svg>

      <div className="legend">
        {holdings.slice(0, 8).map((holding, index) => (
          <div className="legend-row" key={`${holding.schemeCode}-${holding.schemeName}`}>
            <span
              className="legend-swatch"
              style={{ background: PALETTE[index % PALETTE.length] }}
            />
            <span className="legend-name" title={holding.schemeName}>
              {shortName(holding.schemeName)}
            </span>
            <span className="legend-value">
              {holding.allocationPercent.toFixed(1)}%
            </span>
          </div>
        ))}
        {holdings.length === 0 && (
          <span className="small muted">No holdings to chart yet.</span>
        )}
      </div>
    </div>
  );
}

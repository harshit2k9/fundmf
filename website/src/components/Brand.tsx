/** Logo + wordmark. Uses the exact app icon artwork from /logo.png. */
export function Brand({
  onDark = false,
  size = 34,
}: {
  onDark?: boolean;
  size?: number;
}) {
  return (
    <div className={`brand${onDark ? ' on-dark' : ''}`}>
      <img src="/logo.png" alt="Fundmf" width={size} height={size} />
      <div>
        <div className="brand-name">FUNDMF</div>
        <div className="brand-tag">Powered by Compounding</div>
      </div>
    </div>
  );
}

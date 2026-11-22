import { APK_SIZE_LABEL, APK_URL } from '../lib/firebase';

/**
 * Direct APK download. `VITE_APK_URL` points at wherever the binary is hosted;
 * by default the site serves it from /fundmf-release.apk.
 */
export function DownloadApkButton({
  className = 'btn btn-accent btn-sm',
  label = 'Download APK',
}: {
  className?: string;
  label?: string;
}) {
  return (
    <a
      className={className}
      href={APK_URL}
      download="fundmf-release.apk"
      rel="noopener"
      aria-label="Download the Fundmf Android APK"
    >
      ⤓ {label}
    </a>
  );
}

/** Shown on phones so the native app is one tap away. */
export function DownloadApkBanner() {
  return (
    <div className="download-banner">
      <div className="grow">
        <strong>Fundmf for Android</strong>
        <span> native app · {APK_SIZE_LABEL} · sideload directly</span>
      </div>
      <DownloadApkButton />
    </div>
  );
}

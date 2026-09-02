import { useId } from 'react';

// The Centavoo mark: a warm coin engraved with a cent (¢) sign, matching the
// app's orange/warm-gray glass palette. Used in the header and favicon/icons.
export function Logo({ size = 28 }: { size?: number }) {
  const gradId = `centavoo-coin-${useId()}`;
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
      <defs>
        <radialGradient id={gradId} cx="35%" cy="30%" r="75%">
          <stop offset="0%" stopColor="#ffd9a0" />
          <stop offset="45%" stopColor="#ff9f43" />
          <stop offset="100%" stopColor="#d9480f" />
        </radialGradient>
      </defs>
      <circle cx="16" cy="16" r="14.5" fill={`url(#${gradId})`} />
      <circle cx="16" cy="16" r="14.5" fill="none" stroke="#fff3e0" strokeOpacity="0.35" />
      <circle cx="16" cy="16" r="11.2" fill="none" stroke="#fff3e0" strokeOpacity="0.22" />
      <path
        d="M19.6 11.4a6 6 0 1 0 0 9.2"
        fill="none"
        stroke="#3a2413"
        strokeWidth="2.4"
        strokeLinecap="round"
      />
      {/* Tiny paper-plane silhouette standing in for the cent sign's stroke. */}
      <path d="M7 0 L-6 -4 L-2 0 L-6 4 Z" fill="#3a2413" transform="translate(16 16) rotate(-35)" />
    </svg>
  );
}

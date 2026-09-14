import { useId } from 'react';

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
      <path d="M10 0 L-10 -8 L0 0 L-10 8 Z" fill="#3a2413" transform="translate(16 16) rotate(-25) scale(0.7)" />
    </svg>
  );
}

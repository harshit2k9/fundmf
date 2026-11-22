import { useEffect, useState } from 'react';

/** True below the given breakpoint, re-evaluated on resize/orientation. */
export function useMediaQuery(query: string): boolean {
  const getMatch = (): boolean =>
    typeof window !== 'undefined' && window.matchMedia
      ? window.matchMedia(query).matches
      : false;

  const [matches, setMatches] = useState(getMatch);

  useEffect(() => {
    if (!window.matchMedia) return;
    const list = window.matchMedia(query);
    const handler = (event: MediaQueryListEvent) => setMatches(event.matches);
    setMatches(list.matches);
    list.addEventListener('change', handler);
    return () => list.removeEventListener('change', handler);
  }, [query]);

  return matches;
}

/** Phone-sized viewport: the site switches to the app-style mobile UI. */
export const useIsMobile = (): boolean => useMediaQuery('(max-width: 767px)');

/** Matches the app's `width >= 900` wide-layout decision. */
export const useIsWide = (): boolean => useMediaQuery('(min-width: 900px)');

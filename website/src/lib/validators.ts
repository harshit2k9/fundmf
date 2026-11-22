/** Indian PAN / email / phone validation, ported from the Flutter Validators. */

const PAN_PATTERN = /^[A-Z]{5}[0-9]{4}[A-Z]$/;
const EMAIL_PATTERN = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/;
const PHONE_PATTERN = /^[6-9][0-9]{9}$/;

export const normalizeEmail = (value: string): string =>
  (value ?? '').trim().toLowerCase();

export const normalizePan = (value: string): string =>
  (value ?? '').trim().toUpperCase();

export const validateEmail = (value: string): string | null => {
  const v = (value ?? '').trim();
  if (!v) return 'Email address is required';
  if (!EMAIL_PATTERN.test(v)) return 'Enter a valid email address';
  return null;
};

export const validatePassword = (value: string): string | null => {
  const v = value ?? '';
  if (!v) return 'Password is required';
  if (v.length < 8) return 'Use at least 8 characters';
  return null;
};

export const validateConfirmPassword = (
  value: string,
  original: string,
): string | null => {
  if (!(value ?? '')) return 'Confirm your password';
  if (value !== original) return 'Passwords do not match';
  return null;
};

export const validatePan = (value: string): string | null => {
  const v = normalizePan(value);
  if (!v) return 'PAN number is required';
  if (!PAN_PATTERN.test(v)) return 'PAN must look like ABCDE1234F';
  return null;
};

export const validatePhone = (value: string): string | null => {
  const v = (value ?? '').replace(/\D/g, '');
  if (!v) return 'Phone number is required';
  if (!PHONE_PATTERN.test(v)) return 'Enter a 10-digit Indian mobile number';
  return null;
};

export const validateRequired = (
  value: string,
  label: string,
): string | null => ((value ?? '').trim() ? null : `${label} is required`);

export const isValidPan = (value: string): boolean =>
  PAN_PATTERN.test(normalizePan(value));

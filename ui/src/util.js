export const decodeB64 = s => atob(s.replace(/[^A-Za-z0-9+\/=]+/g, ''));
export const encodeB64 = s => btoa(s);
export const hexToChar = h => String.fromCharCode(parseInt(h,16));

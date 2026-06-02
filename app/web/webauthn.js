// WebAuthn (Face ID / passkey) helper for the FitnessAI PWA.
// Exposes three globals called from Dart via dart:js_interop. Keeps all the
// ArrayBuffer <-> base64url handling here (standard, reliable browser code).

function _b64urlToBuf(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  const pad = '='.repeat((4 - (s.length % 4)) % 4);
  const bin = atob(s + pad);
  const b = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) b[i] = bin.charCodeAt(i);
  return b.buffer;
}

function _bufToB64url(buf) {
  const b = new Uint8Array(buf);
  let s = '';
  for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

window.fitnessWebAuthnSupported = function () {
  return !!(window.PublicKeyCredential && navigator.credentials && navigator.credentials.create);
};

// Trigger a browser download of a text file (used for GDPR data export).
window.fitnessDownload = function (filename, text) {
  const blob = new Blob([text], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
};

// options: { challenge, rp_id, rp_name, user_id, user_name, timeout }
window.fitnessWebAuthnRegister = async function (optionsJson) {
  const o = JSON.parse(optionsJson);
  const publicKey = {
    challenge: _b64urlToBuf(o.challenge),
    rp: { id: o.rp_id, name: o.rp_name || 'FitnessAI' },
    user: {
      id: new TextEncoder().encode(o.user_id),
      name: o.user_name,
      displayName: o.user_name,
    },
    pubKeyCredParams: [
      { type: 'public-key', alg: -7 },
      { type: 'public-key', alg: -257 },
    ],
    authenticatorSelection: {
      authenticatorAttachment: 'platform',
      userVerification: 'required',
      residentKey: 'preferred',
    },
    timeout: o.timeout || 60000,
    attestation: 'none',
  };
  const cred = await navigator.credentials.create({ publicKey });
  const resp = cred.response;
  let pub = '';
  try {
    if (resp.getPublicKey) {
      const pk = resp.getPublicKey();
      if (pk) pub = _bufToB64url(pk);
    }
  } catch (e) { /* ignore */ }
  if (!pub) pub = _bufToB64url(resp.attestationObject);
  return JSON.stringify({ credential_id: cred.id, public_key: pub });
};

// options: { rp_id, credential_id, timeout }
window.fitnessWebAuthnAuthenticate = async function (optionsJson) {
  const o = JSON.parse(optionsJson);
  const publicKey = {
    challenge: crypto.getRandomValues(new Uint8Array(32)).buffer,
    rpId: o.rp_id,
    allowCredentials: [{ type: 'public-key', id: _b64urlToBuf(o.credential_id) }],
    userVerification: 'required',
    timeout: o.timeout || 60000,
  };
  const assertion = await navigator.credentials.get({ publicKey });
  const r = assertion.response;
  return JSON.stringify({
    credential_id: assertion.id,
    authenticator_data: _bufToB64url(r.authenticatorData),
    client_data_json: _bufToB64url(r.clientDataJSON),
    signature: _bufToB64url(r.signature),
  });
};

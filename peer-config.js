/* peer-config.js — servidores STUN/TURN para que los móviles conecten aunque estén en otra wifi o con datos.
   Mismas credenciales de Metered que ChronoBeats. El TURN es imprescindible con datos móviles (CGNAT):
   con solo STUN funciona en la misma wifi pero se queda en "conectando" por datos.
   NOTA: las credenciales quedan visibles en el cliente (no hay backend); se pueden rotar desde el panel de Metered. */
(function (root) {
  const ICE_SERVERS = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun.cloudflare.com:3478' },
    { urls: 'stun:stun.relay.metered.ca:80' },
    { urls: 'turn:global.relay.metered.ca:80', username: '10326e2837423e383724ad5c', credential: 'cQjHqkKcCWAIF5OB' },
    { urls: 'turn:global.relay.metered.ca:80?transport=tcp', username: '10326e2837423e383724ad5c', credential: 'cQjHqkKcCWAIF5OB' },
    { urls: 'turn:global.relay.metered.ca:443', username: '10326e2837423e383724ad5c', credential: 'cQjHqkKcCWAIF5OB' },
    { urls: 'turns:global.relay.metered.ca:443?transport=tcp', username: '10326e2837423e383724ad5c', credential: 'cQjHqkKcCWAIF5OB' },
  ];
  root.MK_PEER_OPTIONS = {
    host: '0.peerjs.com', port: 443, secure: true, path: '/', pingInterval: 5000, debug: 1,
    config: { iceCandidatePoolSize: 10, iceServers: ICE_SERVERS },
  };
  root.MK_CONN_OPTIONS = { reliable: true, config: { iceServers: ICE_SERVERS, iceCandidatePoolSize: 10 } };
})(typeof self !== 'undefined' ? self : this);

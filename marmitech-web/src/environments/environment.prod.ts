// Detecta a porta atual do frontend (ex: 4200, 4202) e calcula a porta do backend (+3880)
const currentPort = Number(window.location.port) || 4200;
const backendPort = currentPort + 3880;

export const environment = {
  production: true,
  apiUrl: `${window.location.protocol}//${window.location.hostname}:${backendPort}`
};
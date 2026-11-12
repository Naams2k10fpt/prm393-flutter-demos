import { createHash, randomBytes, randomUUID, scrypt, timingSafeEqual } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { promisify } from 'node:util';
import express from 'express';
import jwt from 'jsonwebtoken';

const hashPassword = promisify(scrypt);
const hashToken = (token) => createHash('sha256').update(token).digest('hex');
const issuer = 'prm393-demo-api';
const audience = 'prm393-demo-app';
const week = 7 * 24 * 60 * 60 * 1000;

export function createApp({ accessTtl = 900 } = {}) {
  if (!Number.isSafeInteger(accessTtl) || accessTtl < 1) {
    throw new Error('ACCESS_TOKEN_TTL_SECONDS phải là số nguyên dương.');
  }

  const app = express();
  const secret = randomBytes(32);
  // shortcut: accounts and sessions reset on restart, use a database for persistent accounts.
  const users = new Map();
  const refreshTokens = new Map();
  const fallbackSalt = randomBytes(16);
  app.disable('x-powered-by');
  app.use(express.json({ limit: '8kb' }));
  app.use((_req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });

  function issueTokens(email, refreshExpiry = Date.now() + week) {
    const now = Date.now();
    for (const [key, entry] of refreshTokens) {
      if (entry.expiresAt <= now) refreshTokens.delete(key);
    }
    const refreshToken = randomBytes(32).toString('base64url');
    const accessToken = jwt.sign({ email }, secret, {
      algorithm: 'HS256',
      subject: users.get(email).id,
      issuer,
      audience,
      expiresIn: accessTtl,
    });
    refreshTokens.set(hashToken(refreshToken), { email, expiresAt: refreshExpiry });
    return { accessToken, refreshToken, expiresIn: accessTtl };
  }

  app.post('/api/auth/register', async (req, res) => {
    const { email: rawEmail, password, fullName: rawName } = req.body ?? {};
    const email = typeof rawEmail === 'string' ? rawEmail.trim().toLowerCase() : '';
    const fullName = typeof rawName === 'string' ? rawName.trim() : '';
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || email.length > 254 ||
        typeof password !== 'string' || [...password].length < 8 || password.length > 128 ||
        !fullName || fullName.length > 100) {
      return res.status(400).json({ message: 'Kiểm tra họ tên, email và mật khẩu (tối thiểu 8 ký tự).' });
    }

    const salt = randomBytes(16);
    const digest = await hashPassword(password, salt, 64);
    if (users.has(email)) {
      return res.status(409).json({ message: 'Email đã được đăng ký.' });
    }
    users.set(email, { id: randomUUID(), email, fullName, salt, digest });
    res.status(201).json({ message: 'Đăng ký thành công. Hãy đăng nhập.' });
  });

  app.post('/api/auth/login', async (req, res) => {
    const { email: rawEmail, password } = req.body ?? {};
    const email = typeof rawEmail === 'string' ? rawEmail.trim().toLowerCase() : '';
    if (!email || email.length > 254 || typeof password !== 'string' ||
        !password || password.length > 128) {
      return res.status(400).json({ message: 'Nhập email và mật khẩu hợp lệ.' });
    }

    const user = users.get(email);
    const digest = await hashPassword(password, user?.salt ?? fallbackSalt, 64);
    if (!user || !timingSafeEqual(user.digest, digest)) {
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng.' });
    }
    res.json(issueTokens(email));
  });

  app.post('/api/auth/refresh', (req, res) => {
    const token = req.body?.refreshToken;
    const key = typeof token === 'string' ? hashToken(token) : '';
    const session = refreshTokens.get(key);
    refreshTokens.delete(key);
    if (!session || session.expiresAt <= Date.now()) {
      return res.status(401).json({ message: 'Phiên đã hết hạn. Hãy đăng nhập lại.' });
    }
    res.json(issueTokens(session.email, session.expiresAt));
  });

  app.post('/api/auth/logout', (req, res) => {
    const token = req.body?.refreshToken;
    if (typeof token === 'string') refreshTokens.delete(hashToken(token));
    res.sendStatus(204);
  });

  app.get('/api/users/me', (req, res) => {
    const [scheme, token, ...extra] = (req.get('Authorization') ?? '').trim().split(/\s+/);
    if (scheme.toLowerCase() === 'bearer' && token && extra.length === 0) {
      try {
        const claims = jwt.verify(token, secret, { algorithms: ['HS256'], issuer, audience });
        const user = users.get(claims.email);
        if (user && user.id === claims.sub) {
          return res.json({ id: user.id, email: user.email, fullName: user.fullName });
        }
      } catch (error) {
        if (!(error instanceof jwt.JsonWebTokenError)) throw error;
      }
    }
    res.status(401).json({ message: 'Access token thiếu, hết hạn hoặc không hợp lệ.' });
  });

  app.use((error, _req, res, _next) => {
    if (error.status === 400 || error.status === 413) {
      return res.status(error.status).json({ message: 'Dữ liệu JSON không hợp lệ hoặc quá lớn.' });
    }
    console.error(error);
    res.status(500).json({ message: 'Lỗi máy chủ.' });
  });
  return app;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const accessTtl = Number(process.env.ACCESS_TOKEN_TTL_SECONDS ?? 900);
  createApp({ accessTtl }).listen(3000, '127.0.0.1', () => {
    console.log(`PRM393 API: http://127.0.0.1:3000 (access token: ${accessTtl}s)`);
  });
}

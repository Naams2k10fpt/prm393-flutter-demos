import assert from 'node:assert/strict';
import { once } from 'node:events';
import { setTimeout } from 'node:timers/promises';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import { createApp } from './server.js';

test('signup, login, protected profile, expiry, refresh rotation and logout', async (t) => {
  const server = createApp({ accessTtl: 2 }).listen(0, '127.0.0.1');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  await once(server, 'listening');
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = (path, body) => fetch(base + '/api/auth/' + path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const profile = (token) => fetch(base + '/api/users/me', {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  const account = { email: 'demo@example.com', password: 'test-only-1234', fullName: 'Demo PRM393' };

  assert.equal((await profile()).status, 401);
  assert.equal((await post('register', { ...account, password: 'short' })).status, 400);
  assert.equal((await post('register', account)).status, 201);
  assert.equal((await post('register', account)).status, 409);
  assert.equal((await post('login', { ...account, password: 'wrong' })).status, 401);

  const login = await post('login', account);
  assert.equal(login.status, 200);
  const { accessToken, refreshToken, expiresIn } = await login.json();
  assert.equal(expiresIn, 2);
  assert.equal((await profile('invalid')).status, 401);
  const me = await profile(accessToken);
  assert.equal(me.status, 200);
  assert.equal((await me.json()).fullName, account.fullName);

  await setTimeout(Math.max(0, jwt.decode(accessToken).exp * 1000 - Date.now()) + 50);
  assert.equal((await profile(accessToken)).status, 401);
  const refresh = await post('refresh', { refreshToken });
  assert.equal(refresh.status, 200);
  const renewed = await refresh.json();
  assert.notEqual(renewed.refreshToken, refreshToken);
  assert.equal((await profile(renewed.accessToken)).status, 200);
  assert.equal((await post('refresh', { refreshToken })).status, 401);

  assert.equal((await post('logout', { refreshToken: renewed.refreshToken })).status, 204);
  assert.equal((await post('refresh', { refreshToken: renewed.refreshToken })).status, 401);
});

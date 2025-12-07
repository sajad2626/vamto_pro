
import jwt from 'jsonwebtoken';

import cookie from 'cookie';

const SECRET = process.env.JWT_SECRET || 'dev_secret_change_me_change';

export function signToken(payload) {

  return jwt.sign(payload, SECRET, { expiresIn: '30d' });

}

export function verifyToken(token) {

  try {

    return jwt.verify(token, SECRET);

  } catch (e) {

    return null;

  }

}

export function setTokenCookie(res, token) {

  const serialized = cookie.serialize('token', token, {

    httpOnly: true,

    secure: process.env.NODE_ENV === 'production',

    sameSite: 'lax',

    path: '/',

    maxAge: 60 * 60 * 24 * 30

  });

  res.setHeader('Set-Cookie', serialized);

}

export function clearTokenCookie(res) {

  const serialized = cookie.serialize('token', '', {

    httpOnly: true,

    secure: process.env.NODE_ENV === 'production',

    sameSite: 'lax',

    path: '/',

    maxAge: 0

  });

  res.setHeader('Set-Cookie', serialized);

}

export function getTokenFromReq(req) {

  const hdr = req.headers?.cookie || '';

  const cookies = cookie.parse(hdr || '');

  return cookies.token || null;

}


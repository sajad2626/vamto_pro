
export const handleError = (res, error, status = 500) => {

  const message = error?.message || error || 'Internal Server Error';

  console.error('[API ERROR]', message);

  return res.status(status).json({ ok: false, error: message });

};

export const handleSuccess = (res, data = {}, status = 200) => {

  return res.status(status).json({ ok: true, ...data });

};


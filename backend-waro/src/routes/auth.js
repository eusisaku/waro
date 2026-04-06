// src/routes/auth.js
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const { supabaseAdmin } = require('../config/supabase');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

// POST /api/auth/register
router.post('/register', [
  body('phoneNumber').isMobilePhone('id-ID').withMessage('Nomor HP tidak valid'),
  body('name').trim().isLength({ min: 2, max: 50 }).withMessage('Nama 2-50 karakter'),
  body('password').isLength({ min: 6 }).withMessage('Password minimal 6 karakter'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { phoneNumber, name, password } = req.body;

  try {
    const { data: existing } = await supabaseAdmin
      .from('users').select('phone_number').eq('phone_number', phoneNumber).single();

    if (existing) return res.status(409).json({ success: false, error: 'Nomor HP sudah terdaftar' });

    const passwordHash = await bcrypt.hash(password, 10);

    const { data: user, error } = await supabaseAdmin
      .from('users')
      .insert({ phone_number: phoneNumber, name, password_hash: passwordHash, pulsa_balance: 20 })
      .select().single();

    if (error) throw error;

    const token = jwt.sign({ userId: user.user_id, phoneNumber: user.phone_number }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
    const { password_hash, ...safeUser } = user;

    res.status(201).json({ success: true, message: 'Pendaftaran berhasil', data: { user: safeUser, token } });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ success: false, error: 'Gagal mendaftar' });
  }
});

// POST /api/auth/login
router.post('/login', [
  body('phoneNumber').isMobilePhone('id-ID').withMessage('Nomor HP tidak valid'),
  body('password').notEmpty().withMessage('Password harus diisi'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { phoneNumber, password } = req.body;

  try {
    const { data: user, error } = await supabaseAdmin
      .from('users').select('*').eq('phone_number', phoneNumber).single();

    if (error || !user) return res.status(401).json({ success: false, error: 'Nomor HP atau password salah' });
    if (!user.is_active) return res.status(403).json({ success: false, error: 'Akun dinonaktifkan' });

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ success: false, error: 'Nomor HP atau password salah' });

    await supabaseAdmin.from('users').update({ last_seen_at: new Date().toISOString() }).eq('user_id', user.user_id);

    const token = jwt.sign({ userId: user.user_id, phoneNumber: user.phone_number }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
    const { password_hash, ...safeUser } = user;

    res.json({ success: true, message: 'Login berhasil', data: { user: safeUser, token } });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// GET /api/auth/verify
router.get('/verify', async (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ success: false, error: 'Token tidak ditemukan' });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const { data: user } = await supabaseAdmin
      .from('users').select('user_id, name, phone_number, pulsa_balance, is_active')
      .eq('user_id', decoded.userId).single();

    if (!user?.is_active) return res.status(401).json({ success: false, error: 'Token tidak valid' });
    res.json({ success: true, data: { user, valid: true } });
  } catch {
    res.status(401).json({ success: false, error: 'Token tidak valid' });
  }
});

module.exports = router;

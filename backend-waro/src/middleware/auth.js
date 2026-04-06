// src/middleware/auth.js
const jwt = require('jsonwebtoken');
const { supabaseAdmin } = require('../config/supabase');

const JWT_SECRET = process.env.JWT_SECRET;

const verifyToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Token tidak ditemukan' });
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.userId = decoded.userId;
    req.phoneNumber = decoded.phoneNumber;

    // Verifikasi user masih aktif
    const { data: user, error } = await supabaseAdmin
      .from('users')
      .select('user_id, is_active')
      .eq('user_id', req.userId)
      .single();

    if (error || !user || !user.is_active) {
      return res.status(401).json({ success: false, error: 'User tidak aktif' });
    }

    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, error: 'Token kadaluarsa, silakan login ulang' });
    }
    return res.status(401).json({ success: false, error: 'Token tidak valid' });
  }
};

module.exports = { verifyToken };

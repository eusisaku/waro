// src/routes/pulsa.js
const express = require('express');
const { body, validationResult } = require('express-validator');
const { supabaseAdmin } = require('../config/supabase');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

// Harga pulsa ekstra
const PULSA_PACKAGES = {
  10: 5000,
  25: 10000,
  60: 20000,
};

// GET /api/pulsa/balance — Cek saldo pulsa
router.get('/balance', async (req, res) => {
  const userId = req.userId;
  try {
    const { data: user, error } = await supabaseAdmin
      .from('users')
      .select('pulsa_balance, name')
      .eq('user_id', userId)
      .single();

    if (error || !user) return res.status(404).json({ success: false, error: 'User tidak ditemukan' });

    // Riwayat 10 transaksi terakhir
    const { data: transactions } = await supabaseAdmin
      .from('pulsa_transactions')
      .select('*')
      .or(`from_user_id.eq.${userId},to_user_id.eq.${userId}`)
      .order('created_at', { ascending: false })
      .limit(10);

    res.json({
      success: true,
      data: {
        balance: user.pulsa_balance,
        daily_limit: 20,
        recent_transactions: transactions || [],
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal cek saldo pulsa' });
  }
});

// POST /api/pulsa/buy — Beli pulsa ekstra
router.post('/buy', [
  body('amount').isInt().withMessage('Jumlah pulsa tidak valid'),
  body('paymentMethod').isIn(['qris', 'ovo', 'shopee_pay', 'dana']).withMessage('Metode pembayaran tidak valid'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { amount, paymentMethod } = req.body;
  const userId = req.userId;

  if (!PULSA_PACKAGES[amount]) {
    const valid = Object.keys(PULSA_PACKAGES).join(', ');
    return res.status(400).json({
      success: false,
      error: `Paket tersedia: ${valid} pulsa`,
    });
  }

  const price = PULSA_PACKAGES[amount];

  try {
    // Simulasi payment gateway (production: integrasikan ke Midtrans / Xendit)
    const paymentRef = `PAY-${Date.now()}-${userId.slice(0, 8).toUpperCase()}`;

    // Tambah pulsa ke user
    const { data: user } = await supabaseAdmin
      .from('users')
      .select('pulsa_balance')
      .eq('user_id', userId)
      .single();

    await supabaseAdmin
      .from('users')
      .update({ pulsa_balance: user.pulsa_balance + amount })
      .eq('user_id', userId);

    // Catat transaksi
    await supabaseAdmin
      .from('pulsa_transactions')
      .insert({
        to_user_id: userId,
        amount,
        price_idr: price,
        transaction_type: 'purchase',
        payment_method: paymentMethod,
        payment_ref: paymentRef,
        status: 'completed',
      });

    res.json({
      success: true,
      message: `${amount} pulsa berhasil ditambahkan`,
      data: {
        added: amount,
        new_balance: user.pulsa_balance + amount,
        price_paid: price,
        payment_ref: paymentRef,
      },
    });
  } catch (err) {
    console.error('Buy pulsa error:', err);
    res.status(500).json({ success: false, error: 'Gagal membeli pulsa' });
  }
});

// POST /api/pulsa/gift — Kirim pulsa ke teman
router.post('/gift', [
  body('toUserId').isUUID().withMessage('ID penerima tidak valid'),
  body('amount').isInt({ min: 1, max: 50 }).withMessage('Kiriman pulsa 1-50'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { toUserId, amount } = req.body;
  const fromUserId = req.userId;

  if (fromUserId === toUserId) {
    return res.status(400).json({ success: false, error: 'Tidak bisa kirim pulsa ke diri sendiri' });
  }

  try {
    // Cek saldo pengirim
    const { data: sender } = await supabaseAdmin
      .from('users').select('name, pulsa_balance').eq('user_id', fromUserId).single();

    if (!sender) return res.status(404).json({ success: false, error: 'Pengirim tidak ditemukan' });
    if (sender.pulsa_balance < amount) {
      return res.status(400).json({
        success: false,
        error: `Saldo tidak cukup. Saldo saat ini: ${sender.pulsa_balance} pulsa`,
      });
    }

    // Cek penerima
    const { data: recipient } = await supabaseAdmin
      .from('users').select('name, pulsa_balance').eq('user_id', toUserId).single();

    if (!recipient) return res.status(404).json({ success: false, error: 'Penerima tidak ditemukan' });

    // Transfer pulsa
    await supabaseAdmin.from('users')
      .update({ pulsa_balance: sender.pulsa_balance - amount }).eq('user_id', fromUserId);
    await supabaseAdmin.from('users')
      .update({ pulsa_balance: recipient.pulsa_balance + amount }).eq('user_id', toUserId);

    // Catat transaksi
    await supabaseAdmin.from('pulsa_transactions').insert({
      from_user_id: fromUserId,
      to_user_id: toUserId,
      amount,
      transaction_type: 'gift',
      status: 'completed',
    });

    // Notifikasi realtime ke penerima
    const io = req.app.get('io');
    const connectedUsers = req.app.get('connectedUsers');
    const recipientSocket = connectedUsers?.get(toUserId);
    if (recipientSocket) {
      io?.to(recipientSocket).emit('pulsa_received', {
        fromUserId,
        fromName: sender.name,
        amount,
        newBalance: recipient.pulsa_balance + amount,
      });
    }

    res.json({
      success: true,
      message: `${amount} pulsa berhasil dikirim ke ${recipient.name}`,
      data: {
        sent: amount,
        from_balance: sender.pulsa_balance - amount,
      },
    });
  } catch (err) {
    console.error('Gift pulsa error:', err);
    res.status(500).json({ success: false, error: 'Gagal mengirim pulsa' });
  }
});

// POST /api/pulsa/use — Pakai pulsa saat kirim pesan (dipanggil internal)
router.post('/use', [
  body('amount').isInt({ min: 1 }).withMessage('Jumlah pulsa tidak valid'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { amount } = req.body;
  const userId = req.userId;

  try {
    const { data: user } = await supabaseAdmin
      .from('users').select('pulsa_balance').eq('user_id', userId).single();

    if (!user) return res.status(404).json({ success: false, error: 'User tidak ditemukan' });
    if (user.pulsa_balance < amount) {
      return res.status(400).json({
        success: false,
        error: 'Pulsa habis. Tunggu besok atau minta ke teman.',
        data: { balance: user.pulsa_balance },
      });
    }

    await supabaseAdmin.from('users')
      .update({ pulsa_balance: user.pulsa_balance - amount })
      .eq('user_id', userId);

    await supabaseAdmin.from('pulsa_transactions').insert({
      to_user_id: userId,
      amount: -amount,
      transaction_type: 'usage',
      status: 'completed',
    });

    res.json({
      success: true,
      data: { used: amount, remaining: user.pulsa_balance - amount },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal menggunakan pulsa' });
  }
});

module.exports = router;

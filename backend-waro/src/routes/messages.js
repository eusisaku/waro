// src/routes/messages.js
const express = require('express');
const { body, validationResult } = require('express-validator');
const { supabaseAdmin } = require('../config/supabase');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

// POST /api/messages/send — Kirim pesan
router.post('/send', [
  body('content').notEmpty().withMessage('Pesan tidak boleh kosong'),
  body('messageType').optional().isIn(['text', 'soundscape', 'urgent']),
  body('recipientId').optional().isUUID(),
  body('warungId').optional().isUUID(),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { recipientId, warungId, content, messageType = 'text', soundscapeUrl, soundscapeDuration } = req.body;
  const senderId = req.userId;

  if (!recipientId && !warungId) {
    return res.status(400).json({ success: false, error: 'Tentukan recipientId atau warungId' });
  }

  try {
    const { data: sender } = await supabaseAdmin.from('users').select('name').eq('user_id', senderId).single();
    if (!sender) return res.status(404).json({ success: false, error: 'Pengirim tidak ditemukan' });

    const io = req.app.get('io');
    const connectedUsers = req.app.get('connectedUsers');

    // ============ PESAN PRIBADI ============
    if (recipientId && !warungId) {
      const { data: recipient } = await supabaseAdmin.from('users').select('user_id, is_active').eq('user_id', recipientId).single();
      if (!recipient?.is_active) return res.status(404).json({ success: false, error: 'Penerima tidak ditemukan' });

      // Cek pause
      const { data: pausedContact } = await supabaseAdmin
        .from('contacts').select('is_paused, pause_until')
        .eq('user_id', recipientId).eq('contact_user_id', senderId).single();

      const isPaused = pausedContact?.is_paused && new Date(pausedContact.pause_until) > new Date();

      if (isPaused && messageType !== 'urgent') {
        // Simpan ke pending
        const { data: pending } = await supabaseAdmin
          .from('pending_messages')
          .insert({ from_user_id: senderId, from_user_name: sender.name, to_user_id: recipientId, content, is_urgent: false })
          .select().single();

        return res.json({ success: true, message: 'Pesan disimpan (penerima pause)', data: { pending, isPending: true } });
      }

      // Kirim normal
      const { data: message, error } = await supabaseAdmin
        .from('messages')
        .insert({ sender_id: senderId, sender_name: sender.name, recipient_id: recipientId, content, message_type: messageType, soundscape_url: soundscapeUrl, soundscape_duration: soundscapeDuration })
        .select().single();

      if (error) throw error;

      // Emit realtime ke penerima
      const recipientSocket = connectedUsers?.get(recipientId);
      if (recipientSocket) {
        io?.to(recipientSocket).emit('new_message', { message });
      }

      return res.json({ success: true, data: { message, isPending: false } });
    }

    // ============ PESAN WARUNG ============
    if (warungId) {
      const { data: member } = await supabaseAdmin
        .from('warung_members').select('warung_id').eq('warung_id', warungId).eq('user_id', senderId).single();

      if (!member) return res.status(403).json({ success: false, error: 'Anda bukan anggota warung ini' });

      const { data: warung } = await supabaseAdmin
        .from('warungs').select('is_active, expires_at').eq('warung_id', warungId).single();

      if (!warung?.is_active || new Date(warung.expires_at) < new Date()) {
        return res.status(400).json({ success: false, error: 'Warung sudah bubar' });
      }

      const { data: message, error } = await supabaseAdmin
        .from('messages')
        .insert({ sender_id: senderId, sender_name: sender.name, warung_id: warungId, content, message_type: messageType })
        .select().single();

      if (error) throw error;

      // Update last message warung
      await supabaseAdmin.from('warungs')
        .update({ last_message: content, last_message_at: new Date().toISOString() })
        .eq('warung_id', warungId);

      // Broadcast ke semua anggota warung
      io?.to(`warung_${warungId}`).emit('new_warung_message', { warungId, message });

      return res.json({ success: true, data: { message } });
    }
  } catch (err) {
    console.error('Send message error:', err);
    res.status(500).json({ success: false, error: 'Gagal mengirim pesan' });
  }
});

// GET /api/messages/inbox — Ambil pesan masuk (untuk sync)
router.get('/inbox', async (req, res) => {
  const userId = req.userId;
  const { since } = req.query; // timestamp ISO

  try {
    let query = supabaseAdmin
      .from('messages')
      .select('*')
      .eq('recipient_id', userId)
      .order('sent_at', { ascending: true });

    if (since) query = query.gt('sent_at', since);

    const { data: messages, error } = await query;
    if (error) throw error;

    // Mark as delivered
    if (messages?.length > 0) {
      await supabaseAdmin.from('messages')
        .update({ is_delivered: true, delivered_at: new Date().toISOString() })
        .eq('recipient_id', userId).eq('is_delivered', false);
    }

    res.json({ success: true, data: { messages: messages || [], count: messages?.length || 0 } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal mengambil pesan' });
  }
});

// PUT /api/messages/:messageId/read — Tandai dibaca
router.put('/:messageId/read', async (req, res) => {
  const { messageId } = req.params;
  try {
    await supabaseAdmin.from('messages')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('message_id', messageId).eq('recipient_id', req.userId);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal update status baca' });
  }
});

module.exports = router;

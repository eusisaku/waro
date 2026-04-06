// src/routes/pause.js
const express = require('express');
const { body, validationResult } = require('express-validator');
const { supabaseAdmin } = require('../config/supabase');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

// POST /api/pause/:contactId — Pause chat dengan teman
router.post('/:contactId', [
  body('durationDays').isInt({ min: 1, max: 7 }).withMessage('Durasi pause 1-7 hari'),
  body('reason').optional().isLength({ max: 150 }),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { contactId } = req.params;
  const { durationDays, reason = 'Perlu istirahat sejenak' } = req.body;
  const userId = req.userId;

  if (contactId === userId) {
    return res.status(400).json({ success: false, error: 'Tidak bisa pause diri sendiri' });
  }

  try {
    const pauseUntil = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();

    // Upsert ke tabel contacts
    const { error } = await supabaseAdmin
      .from('contacts')
      .upsert({
        user_id: userId,
        contact_user_id: contactId,
        is_paused: true,
        pause_until: pauseUntil,
        pause_reason: reason,
      }, { onConflict: 'user_id,contact_user_id' });

    if (error) throw error;

    // Notifikasi realtime ke kontak yang di-pause 
    const io = req.app.get('io');
    const connectedUsers = req.app.get('connectedUsers');

    // Ambil nama user yang pause
    const { data: pauseUser } = await supabaseAdmin
      .from('users').select('name').eq('user_id', userId).single();

    const targetSocket = connectedUsers?.get(contactId);
    if (targetSocket) {
      io?.to(targetSocket).emit('contact_paused', {
        pausedBy: userId,
        pausedByName: pauseUser?.name,
        pauseUntil,
        reason,
      });
    }

    res.json({
      success: true,
      message: `Chat di-pause ${durationDays} hari`,
      data: { pause_until: pauseUntil, reason },
    });
  } catch (err) {
    console.error('Pause error:', err);
    res.status(500).json({ success: false, error: 'Gagal pause chat' });
  }
});

// DELETE /api/pause/:contactId — Unpause (resume) chat
router.delete('/:contactId', async (req, res) => {
  const { contactId } = req.params;
  const userId = req.userId;

  try {
    const { error } = await supabaseAdmin
      .from('contacts')
      .update({ is_paused: false, pause_until: null, pause_reason: null })
      .eq('user_id', userId)
      .eq('contact_user_id', contactId);

    if (error) throw error;

    // Kirim pending messages yang tertahan
    const { data: pendingMessages } = await supabaseAdmin
      .from('pending_messages')
      .select('*')
      .eq('to_user_id', userId)
      .eq('from_user_id', contactId)
      .order('created_at', { ascending: true });

    if (pendingMessages && pendingMessages.length > 0) {
      // Pindah pending ke messages
      const messagesRows = pendingMessages.map((p) => ({
        sender_id: p.from_user_id,
        sender_name: p.from_user_name,
        recipient_id: userId,
        content: p.content,
        message_type: p.is_urgent ? 'urgent' : 'text',
      }));
      await supabaseAdmin.from('messages').insert(messagesRows);

      // Hapus dari pending
      const ids = pendingMessages.map((p) => p.pending_id);
      await supabaseAdmin.from('pending_messages').delete().in('pending_id', ids);

      // Notifikasi realtime
      const io = req.app.get('io');
      const connectedUsers = req.app.get('connectedUsers');
      const userSocket = connectedUsers?.get(userId);
      if (userSocket) {
        io?.to(userSocket).emit('pending_messages_released', {
          fromUserId: contactId,
          count: messagesRows.length,
        });
      }
    }

    res.json({
      success: true,
      message: 'Chat di-resume',
      data: { released_messages: pendingMessages?.length || 0 },
    });
  } catch (err) {
    console.error('Unpause error:', err);
    res.status(500).json({ success: false, error: 'Gagal resume chat' });
  }
});

// GET /api/pause — Daftar semua kontak yang sedang di-pause
router.get('/', async (req, res) => {
  const userId = req.userId;
  try {
    const now = new Date().toISOString();
    const { data: paused, error } = await supabaseAdmin
      .from('contacts')
      .select('contact_user_id, pause_until, pause_reason, users!contacts_contact_user_id_fkey(name)')
      .eq('user_id', userId)
      .eq('is_paused', true)
      .gt('pause_until', now);

    if (error) throw error;

    res.json({ success: true, data: { paused: paused || [] } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal mengambil data pause' });
  }
});

// POST /api/pause/detox — Digital Detox: pause SEMUA kontak
router.post('/detox', [
  body('durationDays').isInt({ min: 1, max: 7 }).withMessage('Durasi detox 1-7 hari'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { durationDays } = req.body;
  const userId = req.userId;
  const pauseUntil = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();

  try {
    // Ambil semua kontak
    const { data: contacts } = await supabaseAdmin
      .from('contacts')
      .select('contact_user_id')
      .eq('user_id', userId);

    if (!contacts || contacts.length === 0) {
      return res.json({ success: true, message: 'Tidak ada kontak untuk di-pause', data: { count: 0 } });
    }

    // Update semua kontak jadi pause
    const { error } = await supabaseAdmin
      .from('contacts')
      .update({ is_paused: true, pause_until: pauseUntil, pause_reason: 'Digital detox' })
      .eq('user_id', userId);

    if (error) throw error;

    res.json({
      success: true,
      message: `Digital detox aktif ${durationDays} hari — semua obrolan dijeda`,
      data: { count: contacts.length, pause_until: pauseUntil },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal mengaktifkan digital detox' });
  }
});

module.exports = router;

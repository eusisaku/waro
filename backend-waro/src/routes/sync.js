// src/routes/sync.js
// Endpoint sinkronisasi bidirectional untuk offline-first Flutter client
const express = require('express');
const { body, validationResult } = require('express-validator');
const { supabaseAdmin } = require('../config/supabase');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

const BATCH_SIZE = 20;

// POST /api/sync/pull — Ambil semua data baru dari server sejak last_sync_at
router.post('/pull', [
  body('lastSyncAt').optional().isISO8601().withMessage('Format timestamp tidak valid'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const userId = req.userId;
  const { lastSyncAt } = req.body;
  const since = lastSyncAt ? new Date(lastSyncAt).toISOString() : new Date(0).toISOString();

  try {
    // Pesan baru (inbox + warung)
    const { data: contactIds } = await supabaseAdmin
      .from('contacts').select('contact_user_id').eq('user_id', userId);
    const { data: warungMember } = await supabaseAdmin
      .from('warung_members').select('warung_id').eq('user_id', userId);

    const warungIds = (warungMember || []).map((w) => w.warung_id);

    // Pesan pribadi masuk
    let msgQuery = supabaseAdmin
      .from('messages')
      .select('*')
      .eq('recipient_id', userId)
      .gt('sent_at', since)
      .order('sent_at', { ascending: true })
      .limit(BATCH_SIZE);

    const { data: privateMessages } = await msgQuery;

    // Pesan warung
    let warungMessages = [];
    if (warungIds.length > 0) {
      const { data: wmsgs } = await supabaseAdmin
        .from('messages')
        .select('*')
        .in('warung_id', warungIds)
        .gt('sent_at', since)
        .order('sent_at', { ascending: true })
        .limit(BATCH_SIZE);
      warungMessages = wmsgs || [];
    }

    // Warungs yang diperbarui
    let updatedWarungs = [];
    if (warungIds.length > 0) {
      const { data: wData } = await supabaseAdmin
        .from('warungs')
        .select('*')
        .in('warung_id', warungIds)
        .gt('updated_at', since);
      updatedWarungs = wData || [];
    }

    // Pending messages untuk user ini
    const { data: pendingMessages } = await supabaseAdmin
      .from('pending_messages')
      .select('*')
      .eq('to_user_id', userId)
      .gt('created_at', since);

    // Status pause yang berubah
    const { data: pausedContacts } = await supabaseAdmin
      .from('contacts')
      .select('contact_user_id, is_paused, pause_until, pause_reason')
      .eq('user_id', userId)
      .gt('updated_at', since);

    // Saldo pulsa terkini
    const { data: user } = await supabaseAdmin
      .from('users').select('pulsa_balance').eq('user_id', userId).single();

    const now = new Date().toISOString();

    res.json({
      success: true,
      data: {
        sync_at: now,
        private_messages: privateMessages || [],
        warung_messages: warungMessages,
        updated_warungs: updatedWarungs,
        pending_messages: pendingMessages || [],
        paused_contacts: pausedContacts || [],
        pulsa_balance: user?.pulsa_balance ?? 0,
        has_more: (privateMessages?.length || 0) >= BATCH_SIZE || warungMessages.length >= BATCH_SIZE,
      },
    });
  } catch (err) {
    console.error('Sync pull error:', err);
    res.status(500).json({ success: false, error: 'Gagal sinkronisasi data' });
  }
});

// POST /api/sync/push — Upload batch operasi offline ke server
router.post('/push', [
  body('operations').isArray({ min: 1, max: 20 }).withMessage('Operasi harus 1-20 item'),
  body('operations.*.type').isIn(['send_message', 'mark_read', 'pause', 'unpause', 'create_warung'])
    .withMessage('Tipe operasi tidak valid'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const userId = req.userId;
  const { operations } = req.body;
  const results = [];
  const failed = [];

  for (const op of operations) {
    try {
      switch (op.type) {
        case 'send_message': {
          const { recipientId, warungId, content, messageType = 'text', localId } = op.payload;
          const { data: sender } = await supabaseAdmin.from('users').select('name').eq('user_id', userId).single();

          const row = {
            sender_id: userId,
            sender_name: sender?.name,
            content,
            message_type: messageType,
          };
          if (recipientId) row.recipient_id = recipientId;
          if (warungId) row.warung_id = warungId;

          const { data: msg } = await supabaseAdmin.from('messages').insert(row).select().single();
          results.push({ localId, serverId: msg?.message_id, type: op.type, success: true });

          // Emit realtime
          const io = req.app.get('io');
          const connectedUsers = req.app.get('connectedUsers');
          if (recipientId) {
            const sock = connectedUsers?.get(recipientId);
            if (sock) io?.to(sock).emit('new_message', { message: msg });
          }
          if (warungId) {
            io?.to(`warung_${warungId}`).emit('new_warung_message', { warungId, message: msg });
          }
          break;
        }

        case 'mark_read': {
          const { messageId } = op.payload;
          await supabaseAdmin.from('messages')
            .update({ is_read: true, read_at: new Date().toISOString() })
            .eq('message_id', messageId).eq('recipient_id', userId);
          results.push({ type: op.type, messageId, success: true });
          break;
        }

        case 'pause': {
          const { contactId, durationDays, reason } = op.payload;
          const pauseUntil = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString();
          await supabaseAdmin.from('contacts').upsert({
            user_id: userId,
            contact_user_id: contactId,
            is_paused: true,
            pause_until: pauseUntil,
            pause_reason: reason,
          }, { onConflict: 'user_id,contact_user_id' });
          results.push({ type: op.type, contactId, success: true });
          break;
        }

        case 'unpause': {
          const { contactId } = op.payload;
          await supabaseAdmin.from('contacts')
            .update({ is_paused: false, pause_until: null, pause_reason: null })
            .eq('user_id', userId).eq('contact_user_id', contactId);
          results.push({ type: op.type, contactId, success: true });
          break;
        }

        case 'create_warung': {
          const { name, description, memberIds, localId } = op.payload;
          const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
          const { data: warung } = await supabaseAdmin
            .from('warungs').insert({ name, description, creator_id: userId, expires_at: expiresAt })
            .select().single();

          const allMembers = [...new Set([...(memberIds || []), userId])];
          await supabaseAdmin.from('warung_members').insert(
            allMembers.map((uid) => ({ warung_id: warung.warung_id, user_id: uid, is_creator: uid === userId }))
          );
          results.push({ localId, serverId: warung?.warung_id, type: op.type, success: true });
          break;
        }

        default:
          failed.push({ type: op.type, error: 'Tipe tidak dikenali' });
      }
    } catch (err) {
      console.error(`Sync push op error [${op.type}]:`, err);
      failed.push({ type: op.type, localId: op.payload?.localId, error: err.message });
    }
  }

  res.json({
    success: true,
    data: {
      processed: results.length,
      failed: failed.length,
      results,
      failed,
      sync_at: new Date().toISOString(),
    },
  });
});

// GET /api/sync/status — Cek status server & saldo pulsa (heartbeat)
router.get('/status', async (req, res) => {
  const userId = req.userId;
  try {
    const { data: user } = await supabaseAdmin
      .from('users').select('pulsa_balance, last_seen_at').eq('user_id', userId).single();

    await supabaseAdmin.from('users')
      .update({ last_seen_at: new Date().toISOString() }).eq('user_id', userId);

    res.json({
      success: true,
      data: {
        server_time: new Date().toISOString(),
        pulsa_balance: user?.pulsa_balance ?? 0,
        last_seen: user?.last_seen_at,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal cek status server' });
  }
});

module.exports = router;

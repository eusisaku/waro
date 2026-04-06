// src/routes/warungs.js
const express = require('express');
const { body, validationResult } = require('express-validator');
const { supabaseAdmin } = require('../config/supabase');
const { verifyToken } = require('../middleware/auth');

const router = express.Router();
router.use(verifyToken);

// GET /api/warungs — Ambil warung aktif user
router.get('/', async (req, res) => {
  const userId = req.userId;
  try {
    const { data: memberships } = await supabaseAdmin
      .from('warung_members')
      .select('warung_id')
      .eq('user_id', userId);

    if (!memberships || memberships.length === 0) {
      return res.json({ success: true, data: { warungs: [] } });
    }

    const warungIds = memberships.map((m) => m.warung_id);

    const { data: warungs, error } = await supabaseAdmin
      .from('warungs')
      .select('*, warung_members(user_id, users(name, phone_number))')
      .in('warung_id', warungIds)
      .eq('is_active', true)
      .order('created_at', { ascending: false });

    if (error) throw error;

    // Hitung persen waktu tersisa
    const now = new Date();
    const enriched = (warungs || []).map((w) => {
      const created = new Date(w.created_at);
      const expires = new Date(w.expires_at);
      const totalMs = expires - created;
      const remainingMs = expires - now;
      const percentRemaining = Math.max(0, Math.min(100, (remainingMs / totalMs) * 100));
      return { ...w, percent_remaining: Math.round(percentRemaining) };
    });

    res.json({ success: true, data: { warungs: enriched } });
  } catch (err) {
    console.error('Get warungs error:', err);
    res.status(500).json({ success: false, error: 'Gagal mengambil data warung' });
  }
});

// GET /api/warungs/:warungId — Detail warung + pesan terakhir
router.get('/:warungId', async (req, res) => {
  const { warungId } = req.params;
  const userId = req.userId;
  try {
    // Cek keanggotaan
    const { data: member } = await supabaseAdmin
      .from('warung_members')
      .select('warung_id')
      .eq('warung_id', warungId)
      .eq('user_id', userId)
      .single();

    if (!member) return res.status(403).json({ success: false, error: 'Anda bukan anggota warung ini' });

    const { data: warung, error } = await supabaseAdmin
      .from('warungs')
      .select('*, warung_members(user_id, joined_at, users(name))')
      .eq('warung_id', warungId)
      .single();

    if (error || !warung) return res.status(404).json({ success: false, error: 'Warung tidak ditemukan' });

    // Pesan terbaru (50 terakhir)
    const { data: messages } = await supabaseAdmin
      .from('messages')
      .select('*')
      .eq('warung_id', warungId)
      .order('sent_at', { ascending: false })
      .limit(50);

    res.json({ success: true, data: { warung, messages: (messages || []).reverse() } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal mengambil detail warung' });
  }
});

// POST /api/warungs — Buat warung baru
router.post('/', [
  body('name').trim().isLength({ min: 2, max: 50 }).withMessage('Nama warung 2-50 karakter'),
  body('description').optional().isLength({ max: 200 }),
  body('memberIds').isArray({ min: 1, max: 4 }).withMessage('Undang 1-4 teman (max 5 orang termasuk kamu)'),
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });

  const { name, description, memberIds } = req.body;
  const creatorId = req.userId;

  // Pastikan creator tidak ada di memberIds
  const uniqueMembers = [...new Set([...memberIds, creatorId])];
  if (uniqueMembers.length > 5) {
    return res.status(400).json({ success: false, error: 'Maksimal 5 anggota per warung' });
  }

  try {
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

    const { data: warung, error: wErr } = await supabaseAdmin
      .from('warungs')
      .insert({ name, description, creator_id: creatorId, expires_at: expiresAt })
      .select()
      .single();

    if (wErr) throw wErr;

    const memberRows = uniqueMembers.map((uid) => ({
      warung_id: warung.warung_id,
      user_id: uid,
      is_creator: uid === creatorId,
    }));

    await supabaseAdmin.from('warung_members').insert(memberRows);

    // Notifikasi realtime ke semua anggota
    const io = req.app.get('io');
    const connectedUsers = req.app.get('connectedUsers');
    memberIds.forEach((uid) => {
      const socketId = connectedUsers?.get(uid);
      if (socketId) io?.to(socketId).emit('warung_created', { warung });
    });

    res.status(201).json({ success: true, message: 'Warung berhasil dibuat!', data: { warung } });
  } catch (err) {
    console.error('Create warung error:', err);
    res.status(500).json({ success: false, error: 'Gagal membuat warung' });
  }
});

// POST /api/warungs/:warungId/extend — Perpanjang warung +24 jam (Premium Rp1.000)
router.post('/:warungId/extend', async (req, res) => {
  const { warungId } = req.params;
  const userId = req.userId;
  try {
    const { data: warung } = await supabaseAdmin
      .from('warungs')
      .select('is_active, expires_at, creator_id')
      .eq('warung_id', warungId)
      .single();

    if (!warung?.is_active) return res.status(400).json({ success: false, error: 'Warung sudah bubar' });
    if (warung.creator_id !== userId) return res.status(403).json({ success: false, error: 'Hanya creator yang bisa perpanjang' });

    const currentExpiry = new Date(warung.expires_at);
    const newExpiry = new Date(Math.max(currentExpiry, Date.now()) + 24 * 60 * 60 * 1000).toISOString();

    await supabaseAdmin.from('warungs').update({ expires_at: newExpiry }).eq('warung_id', warungId);

    // Notifikasi ke semua anggota
    const io = req.app.get('io');
    io?.to(`warung_${warungId}`).emit('warung_extended', { warungId, newExpiry });

    res.json({ success: true, message: 'Warung diperpanjang +24 jam', data: { new_expires_at: newExpiry } });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal memperpanjang warung' });
  }
});

// DELETE /api/warungs/:warungId — Bubarkan warung (creator only)
router.delete('/:warungId', async (req, res) => {
  const { warungId } = req.params;
  const userId = req.userId;
  try {
    const { data: warung } = await supabaseAdmin
      .from('warungs')
      .select('creator_id')
      .eq('warung_id', warungId)
      .single();

    if (!warung) return res.status(404).json({ success: false, error: 'Warung tidak ditemukan' });
    if (warung.creator_id !== userId) return res.status(403).json({ success: false, error: 'Hanya creator yang bisa membubarkan warung' });

    await supabaseAdmin.from('warungs').update({ is_active: false }).eq('warung_id', warungId);

    // Notifikasi bubar
    const io = req.app.get('io');
    io?.to(`warung_${warungId}`).emit('warung_dissolved', { warungId });

    res.json({ success: true, message: 'Warung telah dibubarkan' });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Gagal membubarkan warung' });
  }
});

module.exports = router;

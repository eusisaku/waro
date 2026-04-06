// src/index.js — WARO Backend API Server
require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const cron = require('node-cron');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
});

// ===== MIDDLEWARE =====
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(morgan('dev'));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: { success: false, error: 'Terlalu banyak request. Coba lagi nanti.' },
});
app.use('/api/', limiter);

// ===== ROUTES =====
app.use('/api/auth', require('./routes/auth'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/warungs', require('./routes/warungs'));
app.use('/api/pause', require('./routes/pause'));
app.use('/api/pulsa', require('./routes/pulsa'));
app.use('/api/sync', require('./routes/sync'));

// Health check
app.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'OK',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Endpoint tidak ditemukan' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('❌ Error:', err);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

// ===== SOCKET.IO REALTIME =====
const connectedUsers = new Map(); // userId => socketId

io.on('connection', (socket) => {
  console.log(`🔌 Socket connected: ${socket.id}`);

  socket.on('register', (userId) => {
    connectedUsers.set(userId, socket.id);
    socket.userId = userId;
    console.log(`👤 User ${userId} online`);
    io.emit('user_online', { userId });
  });

  socket.on('join_warung', (warungId) => {
    socket.join(`warung_${warungId}`);
    console.log(`🏠 Socket ${socket.id} joined warung ${warungId}`);
  });

  socket.on('leave_warung', (warungId) => {
    socket.leave(`warung_${warungId}`);
  });

  socket.on('disconnect', () => {
    if (socket.userId) {
      connectedUsers.delete(socket.userId);
      io.emit('user_offline', { userId: socket.userId });
      console.log(`👤 User ${socket.userId} offline`);
    }
  });
});

// Export io untuk digunakan di controllers
app.set('io', io);
app.set('connectedUsers', connectedUsers);

// ===== CRON JOBS =====

// Expire warung setiap jam
cron.schedule('0 * * * *', async () => {
  console.log('⏰ Cron: Expire warungs...');
  try {
    const { supabaseAdmin } = require('./config/supabase');
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('warungs')
      .update({ is_active: false })
      .eq('is_active', true)
      .lt('expires_at', now);
    if (error) console.error('Cron expire error:', error);
    else console.log('✅ Warung expiry check done');
  } catch (e) {
    console.error('Cron error:', e);
  }
});

// Tambah pulsa harian setiap hari 00:00 WIB (17:00 UTC)
cron.schedule('0 17 * * *', async () => {
  console.log('⚡ Cron: Tambah pulsa harian +20...');
  try {
    const { supabaseAdmin } = require('./config/supabase');
    const { data: users } = await supabaseAdmin.from('users').select('user_id, pulsa_balance');
    for (const user of users || []) {
      await supabaseAdmin
        .from('users')
        .update({ pulsa_balance: user.pulsa_balance + 20 })
        .eq('user_id', user.user_id);
    }
    console.log(`✅ Pulsa +20 diberikan ke ${users?.length || 0} user`);
  } catch (e) {
    console.error('Cron pulsa error:', e);
  }
});

// ===== START SERVER =====
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`\n🏠 WARO Backend API`);
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📡 Socket.IO aktif`);
  console.log(`⏰ Cron jobs aktif`);
  console.log(`🌿 Mode: ${process.env.NODE_ENV}\n`);
});

module.exports = { app, io };

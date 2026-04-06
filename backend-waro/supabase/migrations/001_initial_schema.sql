-- =============================================
-- WARO — Supabase PostgreSQL Initial Schema
-- Migration: 001_initial_schema.sql
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- TABLE: users
-- =============================================
CREATE TABLE IF NOT EXISTS users (
  user_id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  phone_number    VARCHAR(20) NOT NULL UNIQUE,
  name            VARCHAR(50) NOT NULL,
  password_hash   TEXT NOT NULL,
  avatar_url      TEXT,
  pulsa_balance   INT NOT NULL DEFAULT 20,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- TABLE: contacts
-- =============================================
CREATE TABLE IF NOT EXISTS contacts (
  contact_id      UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  contact_user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  nickname        VARCHAR(50),
  is_paused       BOOLEAN NOT NULL DEFAULT FALSE,
  pause_until     TIMESTAMPTZ,
  pause_reason    VARCHAR(150),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, contact_user_id)
);

-- =============================================
-- TABLE: warungs (grup 24 jam)
-- =============================================
CREATE TABLE IF NOT EXISTS warungs (
  warung_id       UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name            VARCHAR(50) NOT NULL,
  description     VARCHAR(200),
  creator_id      UUID NOT NULL REFERENCES users(user_id),
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  expires_at      TIMESTAMPTZ NOT NULL,
  last_message    TEXT,
  last_message_at TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- TABLE: warung_members
-- =============================================
CREATE TABLE IF NOT EXISTS warung_members (
  member_id   UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  warung_id   UUID NOT NULL REFERENCES warungs(warung_id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  is_creator  BOOLEAN NOT NULL DEFAULT FALSE,
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(warung_id, user_id)
);

-- =============================================
-- TABLE: messages
-- =============================================
CREATE TYPE message_type_enum AS ENUM ('text', 'soundscape', 'system', 'urgent');

CREATE TABLE IF NOT EXISTS messages (
  message_id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  sender_id           UUID NOT NULL REFERENCES users(user_id),
  sender_name         VARCHAR(50) NOT NULL,
  recipient_id        UUID REFERENCES users(user_id),         -- null jika warung
  warung_id           UUID REFERENCES warungs(warung_id),     -- null jika pribadi
  content             TEXT NOT NULL,
  message_type        message_type_enum NOT NULL DEFAULT 'text',
  soundscape_url      TEXT,               -- URL rekaman suara lingkungan
  soundscape_duration SMALLINT,           -- detik
  is_delivered        BOOLEAN NOT NULL DEFAULT FALSE,
  is_read             BOOLEAN NOT NULL DEFAULT FALSE,
  delivered_at        TIMESTAMPTZ,
  read_at             TIMESTAMPTZ,
  sent_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_recipient CHECK (recipient_id IS NOT NULL OR warung_id IS NOT NULL)
);

-- =============================================
-- TABLE: pending_messages (pesan tertahan saat pause)
-- =============================================
CREATE TABLE IF NOT EXISTS pending_messages (
  pending_id      UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  from_user_id    UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  from_user_name  VARCHAR(50) NOT NULL,
  to_user_id      UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  content         TEXT NOT NULL,
  is_urgent       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- TABLE: pulsa_transactions
-- =============================================
CREATE TYPE pulsa_type_enum AS ENUM ('daily', 'gift', 'purchase', 'usage');
CREATE TYPE pulsa_status_enum AS ENUM ('pending', 'completed', 'failed');

CREATE TABLE IF NOT EXISTS pulsa_transactions (
  transaction_id  UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  from_user_id    UUID REFERENCES users(user_id),
  to_user_id      UUID REFERENCES users(user_id),
  amount          INT NOT NULL,                     -- negatif = dipakai, positif = diterima
  price_idr       INT,                              -- null jika bukan pembelian
  transaction_type pulsa_type_enum NOT NULL,
  payment_method  VARCHAR(30),
  payment_ref     VARCHAR(100),
  status          pulsa_status_enum NOT NULL DEFAULT 'completed',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- TABLE: device_tokens (FCM push notification)
-- =============================================
CREATE TABLE IF NOT EXISTS device_tokens (
  token_id    UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  fcm_token   TEXT NOT NULL UNIQUE,
  device_info TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX IF NOT EXISTS idx_messages_recipient_sent   ON messages(recipient_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_warung_sent      ON messages(warung_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender           ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_contacts_user             ON contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_paused           ON contacts(user_id, is_paused, pause_until);
CREATE INDEX IF NOT EXISTS idx_warung_members_user       ON warung_members(user_id);
CREATE INDEX IF NOT EXISTS idx_warungs_active_expires    ON warungs(is_active, expires_at);
CREATE INDEX IF NOT EXISTS idx_pending_to_user           ON pending_messages(to_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user        ON device_tokens(user_id);

-- =============================================
-- FUNCTION: auto-update updated_at
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_contacts_updated_at
  BEFORE UPDATE ON contacts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_warungs_updated_at
  BEFORE UPDATE ON warungs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE warungs ENABLE ROW LEVEL SECURITY;
ALTER TABLE warung_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulsa_transactions ENABLE ROW LEVEL SECURITY;

-- Allow server-side admin client to bypass RLS
-- (gunakan service_role key, bukan anon key)
CREATE POLICY "Allow admin full access — users"
  ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access — messages"
  ON messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access — contacts"
  ON contacts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access — warungs"
  ON warungs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access — warung_members"
  ON warung_members FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access — pending_messages"
  ON pending_messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow admin full access — pulsa_transactions"
  ON pulsa_transactions FOR ALL USING (true) WITH CHECK (true);
